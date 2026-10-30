///|
/// The access of a registered host function to the kernel of the plugin that calls it.
pub struct CallContext {
  priv plugin : PluginState
}

///|
/// A host function that the embedder registers in a namespace that it chooses.
pub struct HostFunction {
  priv namespace_ : Namespace
  priv name : FunctionName
  priv signature : @engine.Signature
  priv function : (CallContext, Array[@engine.Value]) -> Array[@engine.Value] raise @engine.HostError
}

///|
pub fn HostFunction::new(
  namespace_ : Namespace,
  name : FunctionName,
  signature : @engine.Signature,
  function : (CallContext, Array[@engine.Value]) -> Array[@engine.Value] raise @engine.HostError,
) -> HostFunction {
  { namespace_, name, signature, function, }
}

///|
/// `namespace.name`.
pub fn HostFunction::label(self : HostFunction) -> String {
  "\{self.namespace_.text()}.\{self.name.text()}"
}

///|
/// A manifest that the library refuses: the import that a registration names, and why.
pub(all) suberror ManifestError {
  /// The name is a function that the library links in `extism:host/env`.
  ReservedName(String)
  /// The embedder registered the name before.
  AlreadyRegistered(String)
} derive(Eq, Debug)

///|
pub extend ManifestError with Eq::{equal, not_equal}

///|
pub extend ManifestError with @debug.Debug::{to_repr}

///|
/// The description of one plugin: its module bytes, its limits, its policy, the host functions that
/// the embedder registers and, when it is enabled, the WASI sandbox. The builder steps give a new
/// manifest; the library reads nothing from a file, a URL or the environment.
pub struct Manifest {
  priv module_ : Bytes
  priv limits : Limits
  priv policy : Policy
  priv functions : Array[HostFunction]
  priv sandbox : @wasi.Sandbox?
}

///|
/// A manifest with the module bytes, the default limits, the default policy, no registered host
/// function and no WASI sandbox.
pub fn Manifest::new(module_ : Bytes) -> Manifest {
  {
    module_,
    limits: Limits::default(),
    policy: Policy::default(),
    functions: [],
    sandbox: None,
  }
}

///|
pub fn Manifest::limits(self : Manifest, limits : Limits) -> Manifest {
  { ..self, limits, }
}

///|
pub fn Manifest::policy(self : Manifest, policy : Policy) -> Manifest {
  { ..self, policy, }
}

///|
/// The manifest with the WASI preview 1 sandbox enabled.
pub fn Manifest::wasi(self : Manifest, sandbox : @wasi.Sandbox) -> Manifest {
  { ..self, sandbox: Some(sandbox), }
}

///|
/// The manifest with `function` registered. A name in `extism:host/env` and a name that is already
/// registered are refused.
pub fn Manifest::register(
  self : Manifest,
  function : HostFunction,
) -> Manifest raise ManifestError {
  if function.namespace_.text() == @kernel.import_namespace {
    raise ReservedName(function.label())
  }
  if self.functions.iter().any(f => f.label() == function.label()) {
    raise AlreadyRegistered(function.label())
  }
  { ..self, functions: [..self.functions, function], }
}

///|
/// The Extism host functions that the library links in `extism:host/env`, with their upstream
/// signatures.
pub(all) enum ExtismFunction {
  ConfigGet
  VarGet
  VarSet
  LogTrace
  LogDebug
  LogInfo
  LogWarn
  LogError
  GetLogLevel
  HttpRequest
  HttpStatusCode
  HttpHeaders
} derive(Eq, Debug)

///|
pub extend ExtismFunction with Eq::{equal, not_equal}

///|
pub extend ExtismFunction with @debug.Debug::{to_repr}

///|
pub fn ExtismFunction::all() -> Array[ExtismFunction] {
  [
    ConfigGet,
    VarGet,
    VarSet,
    LogTrace,
    LogDebug,
    LogInfo,
    LogWarn,
    LogError,
    GetLogLevel,
    HttpRequest,
    HttpStatusCode,
    HttpHeaders,
  ]
}

///|
pub fn ExtismFunction::name(self : ExtismFunction) -> String {
  match self {
    ConfigGet => "config_get"
    VarGet => "var_get"
    VarSet => "var_set"
    LogTrace => "log_trace"
    LogDebug => "log_debug"
    LogInfo => "log_info"
    LogWarn => "log_warn"
    LogError => "log_error"
    GetLogLevel => "get_log_level"
    HttpRequest => "http_request"
    HttpStatusCode => "http_status_code"
    HttpHeaders => "http_headers"
  }
}

///|
pub fn ExtismFunction::from_name(name : StringView) -> ExtismFunction? {
  ExtismFunction::all().iter().find_first(f => f.name() == name.to_owned())
}

///|
pub fn ExtismFunction::signature(self : ExtismFunction) -> @engine.Signature {
  match self {
    ConfigGet | VarGet => @engine.Signature::new([I64], [I64])
    VarSet => @engine.Signature::new([I64, I64], [])
    LogTrace | LogDebug | LogInfo | LogWarn | LogError =>
      @engine.Signature::new([I64], [])
    GetLogLevel | HttpStatusCode => @engine.Signature::new([], [I32])
    HttpRequest => @engine.Signature::new([I64, I64], [I64])
    HttpHeaders => @engine.Signature::new([], [I64])
  }
}

///|
/// What links one import of a plugin.
priv enum Link {
  Kernel(@kernel.KernelFunction)
  Extism(ExtismFunction)
  Registered(HostFunction)
  Wasi(@wasi.Function)
}

///|
/// A plugin that the library refuses to load.
pub(all) suberror LoadError {
  /// Nothing links this import: the module and the field.
  UnlinkedImport(String, String)
  /// The import has a signature other than the one that the library links: the import and the
  /// detail.
  WrongSignature(String, String)
  /// The engine refuses the module or its instantiation.
  Engine(@engine.EngineError)
} derive(Debug)

///|
pub extend LoadError with @debug.Debug::{to_repr}

///|
fn wasi_signature(function : @wasi.Function) -> @engine.Signature {
  let convert = (types : Array[@wasi.WasiType]) => {
    types.map(t => {
      match t {
        I32 => @engine.ValueType::I32
        I64 => I64
      }
    })
  }
  @engine.Signature::new(
    convert(function.params()),
    convert(function.results()),
  )
}

///|
fn kernel_signature(function : @kernel.KernelFunction) -> @engine.Signature {
  let convert = (types : Array[@kernel.KernelType]) => {
    types.map(t => {
      match t {
        I32 => @engine.ValueType::I32
        I64 => I64
      }
    })
  }
  @engine.Signature::new(
    convert(function.params()),
    convert(function.results()),
  )
}

///|
/// What links each import, in import order. This is the pure import check of a load: the first import
/// that nothing links refuses the load and is named.
fn Manifest::links(
  self : Manifest,
  imports : Array[@engine.ImportDescriptor],
) -> Array[Link] raise LoadError {
  imports.map(i => {
    let link : Link = if i.module_ == @kernel.import_namespace &&
      @kernel.KernelFunction::from_name(i.name) is Some(function) {
      Kernel(function)
    } else if i.module_ == @kernel.import_namespace &&
      ExtismFunction::from_name(i.name) is Some(function) {
      Extism(function)
    } else if self.functions
      .iter()
      .find_first(f => {
        f.namespace_.text() == i.module_ && f.name.text() == i.name
      })
      is Some(function) {
      Registered(function)
    } else if self.sandbox is Some(_) &&
      i.module_ == @wasi.import_namespace &&
      @wasi.Function::from_name(i.name) is Some(function) {
      Wasi(function)
    } else {
      raise UnlinkedImport(i.module_, i.name)
    }
    let wanted = match link {
      Kernel(function) => kernel_signature(function)
      Extism(function) => function.signature()
      Registered(function) => function.signature
      Wasi(function) => wasi_signature(function)
    }
    guard i.kind is Function(Some(given)) && given == wanted else {
      raise WrongSignature(
        "\{i.module_}.\{i.name}",
        "the library links it as \{wanted}",
      )
    }
    link
  })
}
