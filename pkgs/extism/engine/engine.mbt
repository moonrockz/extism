///|
/// The WASM engine of the target: WAMR on native, `WebAssembly` on js.
pub struct Engine {
  priv features : Array[Feature]
  priv bounds : Bounds
}

///|
/// The engine of the target.
pub fn Engine::default() -> Engine {
  { features: backend_features(), bounds: backend_bounds(), }
}

///|
/// The bounds that the engine enforces.
pub fn Engine::bounds(self : Engine) -> Bounds {
  self.bounds
}

///|
/// The features beyond the core set that the engine supports.
pub fn Engine::features(self : Engine) -> Array[Feature] {
  self.features.copy()
}

///|
fn signature_of(type_ : @binary.FuncType) -> Signature? {
  let convert = (types : Array[@binary.ValType]) => {
    let out : Array[ValueType] = []
    for t in types {
      match t {
        I32 => out.push(I32)
        I64 => out.push(I64)
        F32 => out.push(F32)
        F64 => out.push(F64)
        _ => return None
      }
    }
    Some(out)
  }
  match (convert(type_.params), convert(type_.results)) {
    (Some(params), Some(results)) => Some({ params, results, })
    _ => None
  }
}

///|
/// A compiled module.
pub struct Module {
  priv parsed : @binary.Module
  priv handle : ModuleHandle
}

///|
/// Compiles `bytes`. A module that needs a feature that the engine does not support fails with
/// `FeatureUnsupported` and the name of the feature, before any guest code runs.
pub fn Engine::compile(
  self : Engine,
  bytes : Bytes,
) -> Module raise EngineError {
  let parsed = @binary.Module::parse(bytes) catch {
    DecodeError(at, rule) => raise Invalid("byte \{at}: \{rule}")
  }
  for feature in parsed.features().map(Feature::of) {
    if !self.features.contains(feature) {
      raise FeatureUnsupported(feature)
    }
  }
  if parsed.imports_memory() {
    raise Invalid(
      "the module imports its memory; the engine gives each instance its own memory",
    )
  }
  { parsed, handle: backend_compile(bytes, parsed), }
}

///|
fn extern_kind(
  module_ : @binary.Module,
  kind : @binary.ExportKind,
  index : Int32,
) -> ExternKind {
  match kind {
    Func =>
      Function(
        match module_.function_type(index) {
          Some(type_) => signature_of(type_)
          None => None
        },
      )
    Table => Table
    Memory => Memory
    Global => Global
    Tag => Tag
  }
}

///|
/// The imports of the module, in order.
pub fn Module::imports(self : Module) -> Array[ImportDescriptor] {
  self.parsed.imports.map(i => {
    module_: i.module_,
    name: i.name,
    kind: match i.type_ {
      Func(type_) => Function(signature_of(type_))
      Table => Table
      Memory(_) => Memory
      Global => Global
      Tag => Tag
    },
  })
}

///|
/// The exports of the module, in order.
pub fn Module::exports(self : Module) -> Array[ExportDescriptor] {
  self.parsed.exports.map(e => {
    name: e.name,
    kind: extern_kind(self.parsed, e.kind, e.index),
  })
}

///|
/// The initial pages of the module's memory, or `None` when it has no memory.
pub fn Module::initial_pages(self : Module) -> Int32? {
  match self.parsed.memory() {
    Some(limits) => Some(limits.min.to_int())
    None => None
  }
}

///|
/// What an import is bound to.
priv enum Binding {
  Host(Signature, (Caller, Array[Value]) -> Array[Value] raise HostError)
  Export(Function)
}

///|
priv struct ImportEntry {
  module_ : String
  name : String
  binding : Binding
}

///|
/// The host imports of one instantiation: MoonBit functions and exported functions of other
/// instances, by module name and field name.
pub struct Imports {
  priv entries : Array[ImportEntry]
}

///|
pub fn Imports::new() -> Imports {
  { entries: [], }
}

///|
/// Binds the import `module_.name` to a MoonBit function with the signature `signature`. The
/// function gets the calling instance and the arguments, and gives the results.
pub fn Imports::host(
  self : Imports,
  module_ : String,
  name : String,
  signature : Signature,
  function : (Caller, Array[Value]) -> Array[Value] raise HostError,
) -> Imports {
  self.entries.push({ module_, name, binding: Host(signature, function), })
  self
}

///|
/// Binds the import `module_.name` to an exported function of another instance, so that a guest call
/// of the import runs in that instance.
pub fn Imports::function(
  self : Imports,
  module_ : String,
  name : String,
  function : Function,
) -> Imports {
  self.entries.push({ module_, name, binding: Export(function), })
  self
}

///|
fn Imports::find(self : Imports, module_ : String, name : String) -> Binding? {
  match
    self.entries.iter().find_first(e => e.module_ == module_ && e.name == name) {
    Some(entry) => Some(entry.binding)
    None => None
  }
}

///|
/// The binding of each function import of `module_`, in import order. Every import must be a
/// function with a binding of the same signature.
fn Module::link(
  self : Module,
  imports : Imports,
) -> Array[(String, String, Binding)] raise EngineError {
  let bound = []
  for i in self.parsed.imports {
    let label = "\{i.module_}.\{i.name}"
    guard i.type_ is Func(type_) else {
      raise LinkError(label, "only function imports can be linked")
    }
    guard signature_of(type_) is Some(wanted) else {
      raise LinkError(
        label, "the import has a type other than i32, i64, f32 and f64",
      )
    }
    guard imports.find(i.module_, i.name) is Some(binding) else {
      raise LinkError(label, "nothing is linked for the import \{wanted}")
    }
    let given = match binding {
      Host(signature, _) => signature
      Export(function) => function.signature
    }
    guard given == wanted else {
      raise LinkError(
        label,
        "the module imports \{wanted}, and the given function is \{given}",
      )
    }
    bound.push((i.module_, i.name, binding))
  }
  bound
}

///|
/// An instance of a module, with its own memory.
pub struct Instance {
  priv module_ : Module
  priv handle : InstanceHandle
  priv mut usable : Bool
  /// Instances whose exports this instance calls; they live as long as this one.
  priv linked : Array[Instance]
}

///|
/// Instantiates the module with `imports` and a memory ceiling of `memory_ceiling` pages. A
/// `memory.grow` past the ceiling returns -1 to the guest.
pub fn Module::instantiate(
  self : Module,
  imports : Imports,
  memory_ceiling~ : PageCount = PageCount::default_ceiling(),
) -> Instance raise EngineError {
  let ceiling = memory_ceiling.pages()
  if self.initial_pages() is Some(initial) && initial > ceiling {
    raise CeilingBelowInitial(ceiling, initial)
  }
  let bindings = self.link(imports)
  let linked = bindings.filter_map(b => {
    match b.2 {
      Export(function) => Some(function.instance)
      Host(_, _) => None
    }
  })
  let caller : Ref[Instance?] = Ref(None)
  let handle = backend_instantiate(
    self.handle,
    self.parsed,
    bindings,
    ceiling,
    caller,
  )
  let instance = { module_: self, handle, usable: true, linked, }
  caller.val = Some(instance)
  instance
}

///|
fn check_arguments(
  name : String,
  signature : Signature,
  args : Array[Value],
) -> Unit raise CallError {
  guard args.length() == signature.params.length() &&
    args
    .iter()
    .zip(signature.params.iter())
    .all(pair => pair.0.value_type() == pair.1) else {
    raise ArgumentMismatch(name, "the export takes \{signature}")
  }
}

///|
/// Calls the exported function `name` with `args`. With a budget, the call stops with
/// `BudgetExhausted` when it runs more instructions; with a deadline, it stops with `Interrupted`
/// when the deadline passes, where the engine enforces these bounds. After a trap, an exhausted
/// budget, an interruption, a memory limit or a host error the instance takes no more calls.
pub fn Instance::call(
  self : Instance,
  name : String,
  args : Array[Value],
  budget? : Budget,
  deadline? : Deadline,
) -> Array[Value] raise CallError {
  guard self.usable else { raise Unusable }
  guard self.module_.parsed.export_type(name) is Some(type_) else {
    raise UnknownExport(name)
  }
  guard signature_of(type_) is Some(signature) else {
    raise ArgumentMismatch(
      name, "the export has a type other than i32, i64, f32 and f64",
    )
  }
  check_arguments(name, signature, args)
  backend_take_refused_grow(self.handle) |> ignore
  errdefer {
    self.usable = false
  }
  backend_call(self.handle, name, signature, args, budget, deadline) catch {
    Host(error) => raise Host(error)
    error => {
      if backend_take_refused_grow(self.handle) {
        raise MemoryLimit
      }
      raise error
    }
  }
}

///|
/// Whether the instance exports a function with the name `name`. No guest code runs.
pub fn Instance::has_function(self : Instance, name : String) -> Bool {
  self.module_.parsed.export_type(name) is Some(_)
}

///|
/// Whether a `memory.grow` of this instance was refused since the last call of this function. A
/// caller that links instances, such as the plugin API with its kernel, reads it for each call.
pub fn Instance::take_refused_grow(self : Instance) -> Bool {
  backend_take_refused_grow(self.handle)
}

///|
/// Whether the instance takes more calls: false after a trap of the instance or of an instance whose
/// exports it calls.
pub fn Instance::is_usable(self : Instance) -> Bool {
  self.usable && self.linked.iter().all(i => i.is_usable())
}

///|
/// The exported function `name`, to link it as an import of another instance.
pub fn Instance::export_function(self : Instance, name : String) -> Function? {
  match self.module_.parsed.export_type(name) {
    Some(type_) =>
      match signature_of(type_) {
        Some(signature) => Some({ instance: self, name, signature, })
        None => None
      }
    None => None
  }
}

///|
/// The memory of the instance, or `None` when it has none.
pub fn Instance::memory(self : Instance) -> Memory? {
  match self.module_.parsed.memory() {
    Some(_) => Some({ instance: self, })
    None => None
  }
}

///|
/// An exported function of an instance.
pub struct Function {
  priv instance : Instance
  priv name : String
  priv signature : Signature
}

///|
pub fn Function::signature(self : Function) -> Signature {
  self.signature
}

///|
/// The instance whose host function a guest calls.
pub struct Caller {
  priv instance : Ref[Instance?]
}

///|
/// The memory of the calling instance, or `None` when it has none.
pub fn Caller::memory(self : Caller) -> Memory? {
  match self.instance.val {
    Some(instance) => instance.memory()
    None => None
  }
}

///|
/// The linear memory of an instance.
pub struct Memory {
  priv instance : Instance
}

///|
/// The size of the memory in bytes.
pub fn Memory::size(self : Memory) -> Int64 {
  backend_memory_size(self.instance.handle)
}

///|
/// The `length` bytes at `offset`. An access outside the memory raises `OutOfBounds` and reads
/// nothing.
pub fn Memory::read(
  self : Memory,
  offset : Int64,
  length : Int32,
) -> Bytes raise MemoryError {
  guard length >= 0 && offset >= 0L && offset + length.to_int64() <= self.size() else {
    raise OutOfBounds(offset, length)
  }
  backend_memory_read(self.instance.handle, offset, length)
}

///|
/// Writes `bytes` at `offset`. An access outside the memory raises `OutOfBounds` and writes nothing.
pub fn Memory::write(
  self : Memory,
  offset : Int64,
  bytes : BytesView,
) -> Unit raise MemoryError {
  guard offset >= 0L && offset + bytes.length().to_int64() <= self.size() else {
    raise OutOfBounds(offset, bytes.length())
  }
  backend_memory_write(self.instance.handle, offset, bytes)
}
