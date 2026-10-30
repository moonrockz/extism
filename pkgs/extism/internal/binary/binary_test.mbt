///|
test "Feature scan: simd, threads and memory64 without an engine" {
  let module_ = @binary.Module::parse(@fixtures.features())
  let features = module_.features()
  assert_true(features.contains(Simd))
  assert_true(features.contains(Threads))
  assert_true(features.contains(Memory64))
}

///|
test "the feature scan finds simd in a function body" {
  assert_eq(@binary.Module::parse(@fixtures.simd()).features(), [Simd])
}

///|
test "a core module needs no feature" {
  for
    bytes in [
      @fixtures.add(),
      @fixtures.host(),
      @fixtures.grow(),
      @fixtures.traps(),
    ] {
    assert_eq(@binary.Module::parse(bytes).features(), [])
  }
}

///|
test "imports and exports with their types" {
  let module_ = @binary.Module::parse(@fixtures.host())
  assert_eq(module_.imports, [
    {
      module_: "env",
      name: "add",
      type_: Func({ params: [I64, I64], results: [I64], }),
    },
  ])
  assert_eq(
    module_.export_type("call_add"),
    Some({ params: [I64, I64], results: [I64], }),
  )
  assert_eq(module_.export_type("add"), None)
}

///|
test "memory limits" {
  assert_eq(
    @binary.Module::parse(@fixtures.big()).memory(),
    Some({ min: 16L, max: None, shared: false, is64: false, }),
  )
  assert_eq(@binary.Module::parse(@fixtures.add()).memory(), None)
}

///|
test "bytes that are not a module are refused" {
  assert_true(refused(() => @binary.Module::parse(b"\x00asm")))
  assert_true(refused(() => @binary.Module::parse(b"\x00asm\x0d\x00\x01\x00")))
  assert_true(
    refused(() => @binary.Module::parse(b"\x00asm\x01\x00\x00\x00\x01\x05\x01")),
  )
}

///|
test "the js rewrite sets the memory maximum and adds the grow flag" {
  let rewritten = @binary.Module::parse(@fixtures.grow()).for_js(32)
    |> @binary.Module::parse
  assert_eq(
    rewritten.memory(),
    Some({ min: 1L, max: Some(32L), shared: false, is64: false, }),
  )
  assert_true(
    rewritten.exports
    .iter()
    .any(e => e.name == @binary.grow_flag_export && e.kind == Global),
  )
  // The original exports keep their indices and types.
  assert_eq(
    rewritten.export_type("grow"),
    Some({ params: [I32], results: [I32], }),
  )
  assert_eq(
    rewritten.export_type("size"),
    Some({ params: [], results: [I32], }),
  )
  // One appended function, of type (i32) -> i32.
  assert_eq(rewritten.functions.length(), 4)
  assert_eq(
    rewritten.function_type(3),
    Some({ params: [I32], results: [I32], }),
  )
  assert_eq(rewritten.features(), [])
}

///|
test "the js rewrite keeps a smaller declared maximum and leaves a module with no grow" {
  let rewritten = @binary.Module::parse(@fixtures.big()).for_js(4096)
    |> @binary.Module::parse
  assert_eq(
    rewritten.memory(),
    Some({ min: 16L, max: Some(4096L), shared: false, is64: false, }),
  )
  assert_false(
    rewritten.exports.iter().any(e => e.name == @binary.grow_flag_export),
  )
}

///|
fn refused(read : () -> @binary.Module raise @binary.DecodeError) -> Bool {
  try read() catch {
    DecodeError(_, _) => true
  } noraise {
    _ => false
  }
}
