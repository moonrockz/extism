///|
/// A call of a denied Extism host function: the function and, for `http_request`, the method and the
/// URL of the refused request.
pub(all) struct DeniedCall {
  function : String
  method_ : String?
  url : String?
} derive(Eq, Debug)

///|
pub extend DeniedCall with Eq::{equal, not_equal}

///|
pub extend DeniedCall with @debug.Debug::{to_repr}

///|
/// The memory whose ceiling refused a grow.
pub(all) enum MemoryKind {
  PluginMemory
  KernelMemory
} derive(Eq, Debug)

///|
pub extend MemoryKind with Eq::{equal, not_equal}

///|
pub extend MemoryKind with @debug.Debug::{to_repr}

///|
/// An error of a plugin call.
pub(all) suberror CallError {
  /// The export returned a code that is not 0, or set an error: the code and the error text.
  Plugin(Int32, String)
  /// The plugin called `proc_exit` with a code that is not 0.
  Exit(Int32)
  /// The plugin called an Extism host function that the policy denies.
  Denied(DeniedCall)
  /// A registered host function failed: the function and its message.
  HostFunction(String, String)
  /// A grow of the plugin or the kernel memory was refused, and the call failed.
  MemoryLimit(MemoryKind)
  /// The plugin went past a limit of the library: the name of the limit.
  Limit(String)
  /// The engine stopped the call: a trap, an exhausted budget, an interruption.
  Engine(@engine.CallError)
  /// The start-up of the guest runtime failed.
  Initialization(@engine.CallError)
  /// The plugin exports no function with this name.
  UnknownExport(String)
} derive(Debug)

///|
pub extend CallError with @debug.Debug::{to_repr}

///|
/// Why a host function stopped the call.
priv enum Failure {
  Denied(DeniedCall)
  Limit(String)
  HostFunction(String, String)
  Exit(Int32)
}

///|
/// The state of one plugin that its host functions share.
priv struct PluginState {
  kernel : @engine.Instance
  policy : Policy
  variables : Map[String, Bytes]
  mut variable_bytes : Int32
  mut http_status : Int32
  mut http_headers : Map[String, String]?
  mut failure : Failure?
}

///|
fn PluginState::kernel_call(
  self : PluginState,
  function : @kernel.KernelFunction,
  args : Array[@engine.Value],
) -> Int64 raise @engine.CallError {
  match self.kernel.call(function.name(), args) {
    [I64(value)] => value
    [I32(value)] => value.to_int64()
    _ => 0L
  }
}

///|
fn PluginState::memory(self : PluginState) -> @engine.Memory {
  match self.kernel.memory() {
    Some(memory) => memory
    None => abort("the kernel has a memory")
  }
}

///|
/// The bytes of the block at `handle`; no bytes for handle 0 or an unknown handle.
fn PluginState::read(
  self : PluginState,
  handle : Int64,
) -> Bytes raise @engine.MemoryError {
  if handle == 0L {
    return b""
  }
  let length = self.kernel_call(Length, [I64(handle)]) catch {
    _ => raise OutOfBounds(handle, 0)
  }
  self.memory().read(handle, length.to_int())
}

///|
/// A new block with `bytes`; handle 0 for no bytes.
fn PluginState::allocate(
  self : PluginState,
  bytes : BytesView,
) -> Int64 raise @engine.MemoryError {
  if bytes.length() == 0 {
    return 0L
  }
  let handle = self.kernel_call(Alloc, [I64(bytes.length().to_int64())]) catch {
    _ => raise OutOfBounds(0L, bytes.length())
  }
  if handle == 0L {
    raise OutOfBounds(0L, bytes.length())
  }
  self.memory().write(handle, bytes)
  handle
}

///|
/// Records why the call stops and stops it.
fn PluginState::stop(
  self : PluginState,
  failure : Failure,
) -> @engine.HostError {
  self.failure = Some(failure)
  @engine.HostError("moonrockz/extism: the call stops")
}

///|
/// The text of the block at `handle`.
fn PluginState::text(
  self : PluginState,
  handle : Int64,
) -> String raise @engine.HostError {
  let bytes = self.read(handle) catch {
    OutOfBounds(_, _) =>
      raise @engine.HostError("the plugin gave a handle outside kernel memory")
  }
  @utf8.decode_lossy(bytes)
}

///|
fn handle_arg(args : Array[@engine.Value], index : Int32) -> Int64 {
  match args.get(index) {
    Some(I64(value)) => value
    _ => 0L
  }
}

///|
fn result_handle(handle : Int64) -> Array[@engine.Value] {
  [I64(handle)]
}

///|
fn PluginState::give(
  self : PluginState,
  bytes : BytesView,
) -> Array[@engine.Value] raise @engine.HostError {
  let handle = self.allocate(bytes) catch {
    OutOfBounds(_, _) =>
      raise @engine.HostError("kernel memory has no room for the result")
  }
  result_handle(handle)
}

///|
fn PluginState::config_get(
  self : PluginState,
  args : Array[@engine.Value],
) -> Array[@engine.Value] raise @engine.HostError {
  match self.policy.config {
    Deny =>
      raise self.stop(
        Denied({ function: "config_get", method_: None, url: None, }),
      )
    Empty => result_handle(0L)
    Values(values) =>
      match values.get(self.text(handle_arg(args, 0))) {
        Some(value) => self.give(@utf8.encode(value))
        None => result_handle(0L)
      }
  }
}

///|
fn PluginState::var_get(
  self : PluginState,
  args : Array[@engine.Value],
) -> Array[@engine.Value] raise @engine.HostError {
  match self.policy.variables {
    Deny =>
      raise self.stop(
        Denied({ function: "var_get", method_: None, url: None, }),
      )
    Empty => result_handle(0L)
    Session(_) =>
      match self.variables.get(self.text(handle_arg(args, 0))) {
        Some(value) => self.give(value)
        None => result_handle(0L)
      }
  }
}

///|
fn PluginState::var_set(
  self : PluginState,
  args : Array[@engine.Value],
) -> Array[@engine.Value] raise @engine.HostError {
  guard self.policy.variables is Session(limit) else {
    raise self.stop(Denied({ function: "var_set", method_: None, url: None, }))
  }
  let name = self.text(handle_arg(args, 0))
  let name_bytes = @utf8.encode(name).length()
  let old = match self.variables.get(name) {
    Some(value) => name_bytes + value.length()
    None => 0
  }
  let value_handle = handle_arg(args, 1)
  if value_handle == 0L {
    self.variables.remove(name)
    self.variable_bytes -= old
    return []
  }
  let value = self.read(value_handle) catch {
    OutOfBounds(_, _) =>
      raise @engine.HostError("the plugin gave a handle outside kernel memory")
  }
  let total = self.variable_bytes - old + name_bytes + value.length()
  if total > limit.bytes() {
    raise self.stop(Limit("variable store"))
  }
  self.variables[name] = value
  self.variable_bytes = total
  []
}

///|
fn PluginState::log(
  self : PluginState,
  level : LogLevel,
  args : Array[@engine.Value],
) -> Array[@engine.Value] raise @engine.HostError {
  if self.policy.logging is Sink(threshold, sink) &&
    level.code() >= threshold.code() {
    sink(level, self.text(handle_arg(args, 0)))
  }
  []
}

///|
fn PluginState::get_log_level(self : PluginState) -> Array[@engine.Value] {
  match self.policy.logging {
    Discard => [I32(logging_off)]
    Sink(level, _) => [I32(level.code())]
  }
}

///|
/// The method, the URL and the headers of the JSON request record of `http_request`.
fn http_request_of(text : String) -> (String, String, Map[String, String]) {
  let json = @json.parse(text) catch { _ => Json::null() }
  let method_ = match json {
    { "method": String(m), .. } => m
    _ => "GET"
  }
  let url = match json {
    { "url": String(u), .. } => u
    _ => ""
  }
  let headers : Map[String, String] = Map([])
  if json is { "headers": Object(fields), .. } {
    for name, value in fields {
      if value is String(text) {
        headers[name] = text
      }
    }
  }
  (method_, url, headers)
}

///|
fn PluginState::http_request(
  self : PluginState,
  args : Array[@engine.Value],
) -> Array[@engine.Value] raise @engine.HostError {
  let (method_, url, headers) = http_request_of(self.text(handle_arg(args, 0)))
  guard self.policy.http is Handler(handler) else {
    raise self.stop(
      Denied({
        function: "http_request",
        method_: Some(method_),
        url: Some(url),
      }),
    )
  }
  let body = self.read(handle_arg(args, 1)) catch {
    OutOfBounds(_, _) =>
      raise @engine.HostError("the plugin gave a handle outside kernel memory")
  }
  let response = handler({ method_, url, headers, body, })
  self.http_status = response.status
  self.http_headers = Some(response.headers)
  self.give(response.body)
}

///|
fn PluginState::http_headers(
  self : PluginState,
) -> Array[@engine.Value] raise @engine.HostError {
  match self.http_headers {
    Some(headers) => {
      let object : Map[String, Json] = Map([])
      for name, value in headers {
        object[name] = Json::string(value)
      }
      self.give(@utf8.encode(Json::object(object).stringify()))
    }
    None => result_handle(0L)
  }
}

///|
fn PluginState::extism(
  self : PluginState,
  function : ExtismFunction,
  args : Array[@engine.Value],
) -> Array[@engine.Value] raise @engine.HostError {
  match function {
    ConfigGet => self.config_get(args)
    VarGet => self.var_get(args)
    VarSet => self.var_set(args)
    LogTrace => self.log(Trace, args)
    LogDebug => self.log(Debug, args)
    LogInfo => self.log(Info, args)
    LogWarn => self.log(Warn, args)
    LogError => self.log(Error, args)
    GetLogLevel => self.get_log_level()
    HttpRequest => self.http_request(args)
    HttpStatusCode => [I32(self.http_status)]
    HttpHeaders => self.http_headers()
  }
}

///|
/// The bytes of the block at `handle` in kernel memory.
pub fn CallContext::read(
  self : CallContext,
  handle : Handle,
) -> Bytes raise @engine.MemoryError {
  self.plugin.read(handle.offset())
}

///|
/// A new block in kernel memory with `bytes`.
pub fn CallContext::allocate(
  self : CallContext,
  bytes : BytesView,
) -> Handle raise @engine.MemoryError {
  let offset = self.plugin.allocate(bytes)
  Handle::parse(offset) catch {
    _ => raise OutOfBounds(0L, bytes.length())
  }
}

///|
/// A loaded plugin: its own kernel instance and its instance, with the imports linked.
pub struct Plugin {
  priv state : PluginState
  priv instance : @engine.Instance
  priv limits : Limits
  priv bounds : @engine.Bounds
  priv mut initialized : Bool
}

///|
/// Loads the plugin of `manifest` on `engine`: the import check, the kernel instance, then the
/// plugin instance with each import linked.
pub fn Plugin::load(
  manifest : Manifest,
  engine~ : @engine.Engine = @engine.Engine::default(),
) -> Plugin raise LoadError {
  let module_ = engine.compile(manifest.module_) catch {
    error => raise Engine(error)
  }
  let links = manifest.links(module_.imports())
  let kernel = engine
    .compile(@kernel.bytes())
    .instantiate(
      @engine.Imports::new(),
      memory_ceiling=manifest.limits.kernel_memory,
    ) catch {
      error => raise Engine(error)
    }
  let state = {
    kernel,
    policy: manifest.policy,
    variables: Map([]),
    variable_bytes: 0,
    http_status: 0,
    http_headers: None,
    failure: None,
  }
  let imports = @engine.Imports::new()
  for index, import_ in module_.imports() {
    match links[index] {
      Kernel(function) =>
        match kernel.export_function(function.name()) {
          Some(exported) =>
            imports.function(import_.module_, import_.name, exported) |> ignore
          None => raise UnlinkedImport(import_.module_, import_.name)
        }
      Extism(function) =>
        imports.host(import_.module_, import_.name, function.signature(), (
          _,
          args,
        ) => state.extism(function, args))
        |> ignore
      Registered(function) => {
        let context = { plugin: state, }
        imports.host(import_.module_, import_.name, function.signature, (
          _,
          args,
        ) => {
          (function.function)(context, args) catch {
            HostError(message) =>
              raise state.stop(HostFunction(function.label(), message))
          }
        })
        |> ignore
      }
      Wasi(function) => {
        let sandbox = match manifest.sandbox {
          Some(sandbox) => sandbox
          None => @wasi.Sandbox::new()
        }
        let signature = wasi_signature(function)
        imports.host(import_.module_, import_.name, signature, (caller, args) => {
          guard caller.memory() is Some(memory) else {
            raise @engine.HostError("the plugin has no memory for WASI")
          }
          let values = args.map(v => {
            match v {
              I32(x) => x.to_int64()
              I64(x) => x
              F32(_) | F64(_) => 0L
            }
          })
          match sandbox.call(function, memory, values) {
            Return(errno) => [I32(errno.code())]
            Exit(code) => raise state.stop(Exit(code))
          }
        })
        |> ignore
      }
    }
  }
  let instance = module_.instantiate(
    imports,
    memory_ceiling=manifest.limits.plugin_memory,
    budget?=manifest.limits.budget,
    deadline?=manifest.limits.deadline,
  ) catch {
    error => raise Engine(error)
  }
  {
    state,
    instance,
    limits: manifest.limits,
    bounds: engine.bounds(),
    initialized: false,
  }
}

///|
/// Whether the plugin exports a function with the name `name`. No guest code runs.
pub fn Plugin::has_function(self : Plugin, name : ExportName) -> Bool {
  self.instance.has_function(name.text())
}

///|
/// The bounds that the engine of the plugin enforces.
pub fn Plugin::bounds(self : Plugin) -> @engine.Bounds {
  self.bounds
}

///|
fn Plugin::export_is_unit(self : Plugin, name : String) -> Bool {
  match self.instance.export_function(name) {
    Some(function) => function.signature() == @engine.Signature::new([], [])
    None => false
  }
}

///|
/// Starts the guest runtime once, as upstream Extism does: `_initialize` and `hs_init(0, 0)` for a
/// Haskell module, else `__wasm_call_ctors`, else `_initialize`. A `__wasm_call_ctors` or an
/// `_initialize` of another type than `() -> ()` is not called, and a `__wasm_call_ctors` of another
/// type does not make `_initialize` run. Each call has the budget and the deadline of the limits. The
/// engine runs no start-up export itself.
fn Plugin::initialize(self : Plugin) -> Unit raise CallError {
  if self.initialized {
    return
  }
  self.initialized = true
  let run = (name : String, args : Array[@engine.Value]) => {
    (
      self.instance.call(
        name,
        args,
        budget?=self.limits.budget,
        deadline?=self.limits.deadline,
      )
      |> ignore
    ) catch {
      error => raise Initialization(error)
    }
  }
  if self.instance.has_function("hs_init") {
    if self.export_is_unit("_initialize") {
      run("_initialize", [])
    }
    run("hs_init", [I32(0), I32(0)])
  } else if self.instance.has_function("__wasm_call_ctors") {
    if self.export_is_unit("__wasm_call_ctors") {
      run("__wasm_call_ctors", [])
    }
  } else if self.export_is_unit("_initialize") {
    run("_initialize", [])
  }
}

///|
/// The error text that the plugin set, as upstream decides: a handle that is not 0 with a length
/// that is not 0.
fn Plugin::error_text(self : Plugin) -> String? raise CallError {
  let handle = self.state.kernel_call(ErrorGet, []) catch {
    error => raise Engine(error)
  }
  if handle == 0L {
    return None
  }
  let length = self.state.kernel_call(Length, [I64(handle)]) catch {
    error => raise Engine(error)
  }
  if length == 0L {
    return None
  }
  let bytes = self.state.memory().read(handle, length.to_int()) catch {
      _ => return None
    }
  Some(@utf8.decode_lossy(bytes))
}

///|
fn Plugin::output(self : Plugin) -> Bytes raise CallError {
  let read = () => {
    let offset = self.state.kernel_call(OutputOffset, [])
    let length = self.state.kernel_call(OutputLength, [])
    if length == 0L {
      b""
    } else {
      self.state.memory().read(offset, length.to_int()) catch {
        _ => raise @engine.Trap(MemoryOutOfBounds)
      }
    }
  }
  read() catch {
    error => raise Engine(error)
  }
}

///|
/// Calls the export `name` with `input`: the kernel is reset, the input is put in kernel memory, the
/// export runs with the budget and the deadline of the limits, and the output bytes are returned when
/// it returns 0 and sets no error.
pub fn Plugin::call(
  self : Plugin,
  name : ExportName,
  input : BytesView,
) -> Bytes raise CallError {
  if !self.has_function(name) {
    raise UnknownExport(name.text())
  }
  self.initialize()
  let state = self.state
  state.failure = None
  state.kernel.take_refused_grow() |> ignore
  try {
    state.kernel_call(Reset, []) |> ignore
    if input.length() > 0 {
      let handle = state.kernel_call(Alloc, [I64(input.length().to_int64())])
      if handle == 0L {
        raise @engine.MemoryLimit
      }
      state.memory().write(handle, input) catch {
        _ => raise @engine.MemoryLimit
      }
      state.kernel_call(InputSet, [I64(handle), I64(input.length().to_int64())])
      |> ignore
    }
  } catch {
    MemoryLimit => raise MemoryLimit(KernelMemory)
    error => raise Engine(error)
  }
  let results = self.instance.call(
    name.text(),
    [],
    budget?=self.limits.budget,
    deadline?=self.limits.deadline,
  ) catch {
    error =>
      match (state.failure, error) {
        (Some(Exit(0)), Host(_)) =>
          if self.error_text() is Some(text) {
            raise Plugin(0, text)
          } else {
            return self.output()
          }
        (Some(Exit(code)), Host(_)) => raise Exit(code)
        (Some(Denied(call)), Host(_)) => raise Denied(call)
        (Some(Limit(limit)), Host(_)) => raise Limit(limit)
        (Some(HostFunction(function, message)), Host(_)) =>
          raise HostFunction(function, message)
        (_, MemoryLimit) => raise MemoryLimit(PluginMemory)
        _ =>
          if state.kernel.take_refused_grow() {
            raise MemoryLimit(KernelMemory)
          } else {
            raise Engine(error)
          }
      }
  }
  let code = match results {
    [I32(code)] => code
    _ => 0
  }
  match self.error_text() {
    Some(text) => raise Plugin(code, text)
    None => if code != 0 { raise Plugin(code, "") }
  }
  self.output()
}
