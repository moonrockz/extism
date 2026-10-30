// The native backend: WAMR through the C stub in wamr/extism_engine.c.

///|
type ModuleHandle

///|
type InstanceHandle

///|
extern "C" fn wamr_init(callback : FuncRef[(Int32, UInt64) -> Int32]) -> Int32 = "extism_wamr_init"

///|
#borrow(module_, field)
extern "C" fn wamr_register(module_ : Bytes, field : Bytes) -> Int32 = "extism_wamr_register"

///|
#borrow(wasm, error)
extern "C" fn wamr_load(wasm : Bytes, error : Bytes) -> ModuleHandle = "extism_wamr_load"

///|
#borrow(module_)
extern "C" fn wamr_module_ok(module_ : ModuleHandle) -> Int32 = "extism_wamr_module_ok"

///|
extern "C" fn wamr_linker_new(count : Int32) -> UInt64 = "extism_wamr_linker_new"

///|
extern "C" fn wamr_linker_host(
  linker : UInt64,
  index : Int32,
  symbol : Int32,
  host : Int32,
) = "extism_wamr_linker_host"

///|
#borrow(target, name)
extern "C" fn wamr_linker_export(
  linker : UInt64,
  index : Int32,
  symbol : Int32,
  target : InstanceHandle,
  name : Bytes,
) -> Int32 = "extism_wamr_linker_export"

///|
#borrow(module_, error)
extern "C" fn wamr_instantiate(
  module_ : ModuleHandle,
  linker : UInt64,
  max_pages : Int32,
  stack_size : Int32,
  error : Bytes,
) -> InstanceHandle = "extism_wamr_instantiate"

///|
#borrow(instance)
extern "C" fn wamr_instance_ok(instance : InstanceHandle) -> Int32 = "extism_wamr_instance_ok"

///|
#borrow(instance, name, cells)
extern "C" fn wamr_call(
  instance : InstanceHandle,
  name : Bytes,
  cells : FixedArray[UInt64],
  budget : Int32,
  deadline : Int32,
) -> Int32 = "extism_wamr_call"

///|
#borrow(instance)
extern "C" fn wamr_take_grow_refused(instance : InstanceHandle) -> Int32 = "extism_wamr_take_grow_refused"

///|
#borrow(instance)
extern "C" fn wamr_memory_size(instance : InstanceHandle) -> Int64 = "extism_wamr_memory_size"

///|
#borrow(instance, out)
extern "C" fn wamr_memory_read(
  instance : InstanceHandle,
  offset : Int64,
  out : Bytes,
  out_offset : Int32,
  length : Int32,
) -> Int32 = "extism_wamr_memory_read"

///|
#borrow(instance, bytes)
extern "C" fn wamr_memory_write(
  instance : InstanceHandle,
  offset : Int64,
  bytes : Bytes,
  bytes_offset : Int32,
  length : Int32,
) -> Int32 = "extism_wamr_memory_write"

///|
extern "C" fn wamr_cell_get(cells : UInt64, index : Int32) -> UInt64 = "extism_wamr_cell_get"

///|
extern "C" fn wamr_cell_set(cells : UInt64, index : Int32, value : UInt64) = "extism_wamr_cell_set"

///|
extern "C" fn wamr_live_watchdogs() -> Int32 = "extism_wamr_live_watchdogs"

///|
/// The number of deadline watchdog threads that run now. After every call it is 0.
pub fn live_watchdogs() -> Int32 {
  wamr_live_watchdogs()
}

///|
priv struct HostEntry {
  signature : Signature
  function : (Caller, Array[Value]) -> Array[Value] raise HostError
  caller : Caller
}

///|
let host_entries : Map[Int32, HostEntry] = Map([])

///|
let next_host_id : Ref[Int32] = Ref(0)

///|
/// The error of the last host function that failed, for the call that it ended.
let last_host_error : Ref[HostError?] = Ref(None)

///|
fn to_cell(value : Value) -> UInt64 {
  match value {
    I32(v) => v.reinterpret_as_uint().to_uint64()
    I64(v) => v.reinterpret_as_uint64()
    F32(v) => v.reinterpret_as_uint().to_uint64()
    F64(v) => v.reinterpret_as_uint64()
  }
}

///|
fn from_cell(type_ : ValueType, cell : UInt64) -> Value {
  match type_ {
    I32 => I32(cell.to_uint().reinterpret_as_int())
    I64 => I64(cell.reinterpret_as_int64())
    F32 => F32(Float::reinterpret_from_uint(cell.to_uint()))
    F64 => F64(cell.reinterpret_as_double())
  }
}

///|
fn dispatch(host_id : Int32, cells : UInt64) -> Int32 {
  guard host_entries.get(host_id) is Some(entry) else { return 1 }
  let args = entry.signature.params.mapi((i, t) => {
    from_cell(t, wamr_cell_get(cells, i))
  })
  let results = (entry.function)(entry.caller, args) catch {
    error => {
      last_host_error.val = Some(error)
      return 1
    }
  }
  guard results.length() == entry.signature.results.length() &&
    results
    .iter()
    .zip(entry.signature.results.iter())
    .all(pair => pair.0.value_type() == pair.1) else {
    last_host_error.val = Some(
      HostError(
        "the host function gave results that do not match \{entry.signature}",
      ),
    )
    return 1
  }
  results.eachi((i, value) => wamr_cell_set(cells, i, to_cell(value)))
  0
}

///|
let initialized : Ref[Bool] = Ref(false)

///|
fn ensure_init() -> Unit {
  if !initialized.val {
    guard wamr_init(fn(host_id, cells) { dispatch(host_id, cells) }) == 1 else {
      abort("moonrockz/extism: the WAMR runtime cannot start")
    }
    initialized.val = true
  }
}

///|
fn backend_features() -> Array[Feature] {
  []
}

///|
fn backend_bounds() -> Bounds {
  { memory: Enforced, budget: Enforced, interruption: Enforced, }
}

///|
fn error_text(buffer : Bytes) -> String {
  let length = buffer.iter().take_while(b => b != b'\x00').count()
  @utf8.decode_lossy(buffer[0:length])
}

///|
fn backend_compile(
  bytes : Bytes,
  parsed : @binary.Module,
) -> ModuleHandle raise EngineError {
  ensure_init()
  // WAMR resolves each import at load, so every name is registered first.
  for i in parsed.imports {
    wamr_register(@utf8.encode(i.module_), @utf8.encode(i.name)) |> ignore
  }
  let error = Bytes::make(256, b'\x00')
  let handle = wamr_load(bytes, error)
  guard wamr_module_ok(handle) == 1 else { raise Invalid(error_text(error)) }
  handle
}

///|
/// The stack of each instance, in bytes.
let stack_size : Int32 = 1024 * 1024

///|
fn backend_instantiate(
  module_ : ModuleHandle,
  _parsed : @binary.Module,
  bindings : Array[(String, String, Binding)],
  ceiling : Int32,
  caller : Ref[Instance?],
) -> InstanceHandle raise EngineError {
  let linker = wamr_linker_new(bindings.length())
  for index, binding in bindings {
    let (module_name, name, kind) = binding
    let symbol = wamr_register(@utf8.encode(module_name), @utf8.encode(name))
    match kind {
      Host(signature, function) => {
        let id = next_host_id.val
        next_host_id.val += 1
        host_entries[id] = {
          signature,
          function,
          caller: { instance: caller, },
        }
        wamr_linker_host(linker, index, symbol, id)
      }
      Export(function) => {
        let found = wamr_linker_export(
          linker,
          index,
          symbol,
          function.instance.handle,
          @utf8.encode(function.name),
        )
        guard found == 1 else {
          raise LinkError(
            "\{module_name}.\{name}",
            "the linked instance has no export \{function.name}",
          )
        }
      }
    }
  }
  let error = Bytes::make(256, b'\x00')
  let handle = wamr_instantiate(module_, linker, ceiling, stack_size, error)
  guard wamr_instance_ok(handle) == 1 else { raise Invalid(error_text(error)) }
  handle
}

///|
fn trap_of(status : Int32) -> CallError {
  match status {
    10 => Trap(Unreachable)
    11 => Trap(MemoryOutOfBounds)
    12 => Trap(DivideByZero)
    13 => Trap(IntegerOverflow)
    14 => Trap(InvalidConversion)
    15 => Trap(StackExhausted)
    16 => Trap(IndirectCall)
    17 =>
      match last_host_error.val {
        Some(error) => {
          last_host_error.val = None
          Host(error)
        }
        None => Trap(Host)
      }
    18 => Trap(TableOutOfBounds)
    20 => BudgetExhausted
    21 => Interrupted
    _ => Trap(Other)
  }
}

///|
fn backend_call(
  handle : InstanceHandle,
  name : String,
  signature : Signature,
  args : Array[Value],
  budget : Budget?,
  deadline : Deadline?,
) -> Array[Value] raise CallError {
  let width = @cmp.maximum(
    signature.params.length(),
    signature.results.length(),
  )
  let cells = FixedArray::make(@cmp.maximum(width, 1), 0UL)
  args.eachi((i, value) => cells[i] = to_cell(value))
  last_host_error.val = None
  let status = wamr_call(
    handle,
    @utf8.encode(name),
    cells,
    match budget {
      Some(b) => b.instructions()
      None => -1
    },
    match deadline {
      Some(d) => d.milliseconds()
      None => -1
    },
  )
  match status {
    0 => signature.results.mapi((i, t) => from_cell(t, cells[i]))
    1 => raise UnknownExport(name)
    2 =>
      raise ArgumentMismatch(
        name, "the export has more than 16 parameters or results",
      )
    _ => raise trap_of(status)
  }
}

///|
fn backend_take_refused_grow(handle : InstanceHandle) -> Bool {
  wamr_take_grow_refused(handle) == 1
}

///|
fn backend_memory_size(handle : InstanceHandle) -> Int64 {
  @cmp.maximum(wamr_memory_size(handle), 0L)
}

///|
fn backend_memory_read(
  handle : InstanceHandle,
  offset : Int64,
  length : Int32,
) -> Bytes raise MemoryError {
  let out = Bytes::make(length, b'\x00')
  guard wamr_memory_read(handle, offset, out, 0, length) == 1 else {
    raise OutOfBounds(offset, length)
  }
  out
}

///|
fn backend_memory_write(
  handle : InstanceHandle,
  offset : Int64,
  bytes : BytesView,
) -> Unit raise MemoryError {
  guard wamr_memory_write(handle, offset, bytes.to_owned(), 0, bytes.length()) ==
    1 else {
    raise OutOfBounds(offset, bytes.length())
  }
}
