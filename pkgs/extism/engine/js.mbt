// The js backend: the `WebAssembly` API of Node.js and browsers (design ENG-3). The memory ceiling and
// the record of a refused `memory.grow` come from the rewrite of `@binary.Module::for_js`.

///|
#external
priv type JsValue

///|
priv struct ModuleHandle {
  parsed : @binary.Module
  /// The compiled module for each ceiling.
  compiled : Map[Int32, JsValue]
}

///|
priv struct InstanceHandle {
  instance : JsValue
}

///|
extern "js" fn js_validate(bytes : Bytes) -> Bool = "(b) => WebAssembly.validate(b)"

///|
extern "js" fn js_compile_error(bytes : Bytes) -> String =
  #|(b) => { try { new WebAssembly.Module(b); return ""; } catch (e) { return String(e && e.message || e); } }

///|
extern "js" fn js_compile(bytes : Bytes) -> JsValue = "(b) => new WebAssembly.Module(b)"

///|
extern "js" fn js_object() -> JsValue = "() => ({})"

///|
extern "js" fn js_set_import(
  imports : JsValue,
  module_ : String,
  name : String,
  value : JsValue,
) = "(i, m, n, v) => { (i[m] ??= {})[n] = v; }"

///|
/// A JS function for a host import. The callback gets the arguments as a JS array and gives the
/// results as a JS array, or `null` when the host function failed.
extern "js" fn js_host(callback : (JsValue) -> JsValue) -> JsValue =
  #|(callback) => function (...args) {
  #|  const results = callback(args);
  #|  if (results === null) throw (globalThis.__moonrockz_extism_host_failure ??= { host: true });
  #|  return results.length === 0 ? undefined : results.length === 1 ? results[0] : results;
  #|}

///|
/// Instantiates `module` with `imports`; gives the instance, or the error message as a string.
extern "js" fn js_instantiate(module_ : JsValue, imports : JsValue) -> JsValue =
  #|(m, i) => { try { return { instance: new WebAssembly.Instance(m, i) }; } catch (e) { return { error: e }; } }

///|
extern "js" fn js_instantiated(result : JsValue) -> JsValue = "(r) => r.instance"

///|
extern "js" fn js_failed(result : JsValue) -> Bool = "(r) => r.instance === undefined"

///|
extern "js" fn js_error_status(result : JsValue) -> Int32 =
  #|(r) => {
  #|  const e = r.error;
  #|  if (e === globalThis.__moonrockz_extism_host_failure) return 17;
  #|  const text = String(e && e.message || e);
  #|  if (e instanceof RangeError && /call stack/i.test(text)) return 15;
  #|  if (/unreachable/i.test(text)) return 10;
  #|  if (/memory access out of bounds|out of bounds memory|index out of bounds/i.test(text) && !/table/i.test(text)) return 11;
  #|  if (/divi(de|sion) by zero/i.test(text)) return 12;
  #|  if (/integer overflow/i.test(text)) return 13;
  #|  if (/unrepresentable|invalid conversion/i.test(text)) return 14;
  #|  if (/table/i.test(text) && /bounds/i.test(text)) return 18;
  #|  if (/signature mismatch|indirect call|null function|uninitialized element|function type/i.test(text)) return 16;
  #|  if (e instanceof WebAssembly.LinkError) return 30;
  #|  if (e instanceof WebAssembly.RuntimeError) return 19;
  #|  return 31;
  #|}

///|
extern "js" fn js_error_message(result : JsValue) -> String = "(r) => String(r.error && r.error.message || r.error)"

///|
/// Calls the export `name`; gives `{ results }` or `{ error }`.
extern "js" fn js_call(
  instance : JsValue,
  name : String,
  args : JsValue,
) -> JsValue =
  #|(inst, name, args) => {
  #|  try {
  #|    const r = inst.exports[name](...args);
  #|    return { instance: true, results: r === undefined ? [] : Array.isArray(r) ? r : [r] };
  #|  } catch (e) { return { error: e }; }
  #|}

///|
extern "js" fn js_results(result : JsValue) -> JsValue = "(r) => r.results"

///|
extern "js" fn js_export(instance : JsValue, name : String) -> JsValue = "(i, n) => i.exports[n]"

///|
extern "js" fn js_array() -> JsValue = "() => []"

///|
extern "js" fn js_push_number(array : JsValue, value : Double) = "(a, v) => { a.push(v); }"

///|
extern "js" fn js_push_i64(array : JsValue, high : Int32, low : Int32) = "(a, h, l) => { a.push(BigInt.asIntN(64, (BigInt(h) << 32n) | BigInt(l >>> 0))); }"

///|
extern "js" fn js_get_number(array : JsValue, index : Int32) -> Double = "(a, i) => Number(a[i])"

///|
extern "js" fn js_get_i64_high(array : JsValue, index : Int32) -> Int32 = "(a, i) => Number(BigInt.asIntN(32, BigInt.asIntN(64, BigInt(a[i])) >> 32n))"

///|
extern "js" fn js_get_i64_low(array : JsValue, index : Int32) -> Int32 = "(a, i) => Number(BigInt.asIntN(32, BigInt(a[i])))"

///|
extern "js" fn js_null() -> JsValue = "() => null"

///|
extern "js" fn js_take_grow(instance : JsValue, flag : String) -> Bool =
  #|(i, f) => { const g = i.exports[f]; if (!g) return false; const v = g.value; g.value = 0; return v !== 0; }

///|
extern "js" fn js_memory_size(instance : JsValue, name : String) -> Double = "(i, m) => i.exports[m] ? i.exports[m].buffer.byteLength : 0"

///|
extern "js" fn js_memory_read(
  instance : JsValue,
  name : String,
  offset : Double,
  length : Int32,
) -> Bytes = "(i, m, o, n) => new Uint8Array(i.exports[m].buffer, o, n).slice()"

///|
extern "js" fn js_memory_write(
  instance : JsValue,
  name : String,
  offset : Double,
  bytes : Bytes,
) = "(i, m, o, b) => { new Uint8Array(i.exports[m].buffer).set(b, o); }"

///|
fn backend_features() -> Array[Feature] {
  [Simd]
}

///|
fn backend_bounds() -> Bounds {
  { memory: Enforced, budget: NotEnforced, interruption: NotEnforced, }
}

///|
fn backend_compile(
  bytes : Bytes,
  parsed : @binary.Module,
) -> ModuleHandle raise EngineError {
  guard js_validate(bytes) else { raise Invalid(js_compile_error(bytes)) }
  { parsed, compiled: Map([]), }
}

///|
fn push_value(array : JsValue, value : Value) -> Unit {
  match value {
    I32(v) => js_push_number(array, v.to_double())
    I64(v) => js_push_i64(array, (v >> 32).to_int(), v.to_int())
    F32(v) => js_push_number(array, v.to_double())
    F64(v) => js_push_number(array, v)
  }
}

///|
fn get_value(array : JsValue, index : Int32, type_ : ValueType) -> Value {
  match type_ {
    I32 => I32(js_get_number(array, index).to_int())
    I64 =>
      I64(
        (js_get_i64_high(array, index).to_int64() << 32) |
        js_get_i64_low(array, index)
        .reinterpret_as_uint()
        .to_uint64()
        .reinterpret_as_int64(),
      )
    F32 => F32(Float::from_double(js_get_number(array, index)))
    F64 => F64(js_get_number(array, index))
  }
}

///|
/// The error of the last host function that failed, for the call that it ended.
let last_host_error : Ref[HostError?] = Ref(None)

///|
fn host_function(
  signature : Signature,
  function : (Caller, Array[Value]) -> Array[Value] raise HostError,
  caller : Ref[Instance?],
) -> JsValue {
  js_host(args => {
    let values = signature.params.mapi((i, t) => get_value(args, i, t))
    let memory = match caller.val {
      Some(instance) => instance.memory()
      None => None
    }
    let results = function({ memory, }, values) catch {
      error => {
        last_host_error.val = Some(error)
        return js_null()
      }
    }
    guard results.length() == signature.results.length() &&
      results
      .iter()
      .zip(signature.results.iter())
      .all(pair => pair.0.value_type() == pair.1) else {
      last_host_error.val = Some(
        HostError(
          "the host function gave results that do not match \{signature}",
        ),
      )
      return js_null()
    }
    let out = js_array()
    for value in results {
      push_value(out, value)
    }
    out
  })
}

///|
fn status_error(status : Int32, message : String) -> CallError {
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
    19 => Trap(Other)
    _ => Host(HostError(message))
  }
}

///|
fn backend_instantiate(
  module_ : ModuleHandle,
  _parsed : @binary.Module,
  bindings : Array[(String, String, Binding)],
  ceiling : Int32,
  caller : Ref[Instance?],
) -> InstanceHandle raise EngineError {
  let compiled = match module_.compiled.get(ceiling) {
    Some(compiled) => compiled
    None => {
      let rewritten = module_.parsed.for_js(ceiling) catch {
        DecodeError(at, rule) => raise Invalid("byte \{at}: \{rule}")
      }
      let compiled = js_compile(rewritten)
      module_.compiled[ceiling] = compiled
      compiled
    }
  }
  let imports = js_object()
  for binding in bindings {
    let (module_name, name, kind) = binding
    let value = match kind {
      Host(signature, function) =>
        host_function(signature, function, caller)
      Export(function) =>
        js_export(function.instance.handle.instance, function.name)
    }
    js_set_import(imports, module_name, name, value)
  }
  // The prepared module has no start section, so no guest code runs here.
  let result = js_instantiate(compiled, imports)
  if js_failed(result) {
    raise Invalid(js_error_message(result))
  }
  { instance: js_instantiated(result), }
}

///|
fn backend_call(
  handle : InstanceHandle,
  name : String,
  signature : Signature,
  args : Array[Value],
  _budget : Budget?,
  _deadline : Deadline?,
) -> Array[Value] raise CallError {
  let array = js_array()
  for value in args {
    push_value(array, value)
  }
  last_host_error.val = None
  let result = js_call(handle.instance, name, array)
  if js_failed(result) {
    raise status_error(js_error_status(result), js_error_message(result))
  }
  let results = js_results(result)
  signature.results.mapi((i, t) => get_value(results, i, t))
}

///|
fn backend_take_refused_grow(handle : InstanceHandle) -> Bool {
  js_take_grow(handle.instance, @binary.grow_flag_export)
}

///|
fn backend_memory_size(handle : InstanceHandle) -> Int64 {
  // The prepared module exports memory 0 under a reserved name, whether or not the module exports it.
  js_memory_size(handle.instance, @binary.memory_export).to_int64()
}

///|
fn backend_memory_read(
  handle : InstanceHandle,
  offset : Int64,
  length : Int32,
) -> Bytes raise MemoryError {
  guard offset + length.to_int64() <= backend_memory_size(handle) else {
    raise OutOfBounds(offset, length)
  }
  js_memory_read(
    handle.instance,
    @binary.memory_export,
    offset.to_double(),
    length,
  )
}

///|
fn backend_memory_write(
  handle : InstanceHandle,
  offset : Int64,
  bytes : BytesView,
) -> Unit raise MemoryError {
  guard offset + bytes.length().to_int64() <= backend_memory_size(handle) else {
    raise OutOfBounds(offset, bytes.length())
  }
  js_memory_write(
    handle.instance,
    @binary.memory_export,
    offset.to_double(),
    bytes.to_owned(),
  )
}
