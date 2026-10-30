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

///|
/// Reads `bytes` as the engines do: the parse, the global scan and both rewrites. A refusal is a
/// `DecodeError`; any other end of the test (a panic) fails it.
fn read_all(bytes : Bytes) -> Unit {
  let module_ = @binary.Module::parse(bytes) catch {
    DecodeError(_, _) => return
  }
  (module_.uses_globals() |> ignore) catch {
    DecodeError(_, _) => ()
  }
  (module_.for_js(256) |> ignore) catch {
    DecodeError(_, _) => ()
  }
}

///|
let fuzz_fixtures : Array[Bytes] = [
  @fixtures.add(),
  @fixtures.big(),
  @fixtures.fd_write_import(),
  @fixtures.features(),
  @fixtures.grow(),
  @fixtures.host(),
  @fixtures.init_trap(),
  @fixtures.link(),
  @fixtures.plugin(),
  @fixtures.simd(),
  @fixtures.simd_probe(),
  @fixtures.traps(),
  @fixtures.unknown_import(),
  @fixtures.wasi_plugin(),
]

///|
test "Parser fuzz: every truncation of every fixture is refused or read, never a panic" {
  for bytes in fuzz_fixtures {
    for length in 0..<=bytes.length() {
      read_all(bytes[0:length].to_owned())
    }
  }
}

///|
test "Parser fuzz: changed bytes are refused or read, never a panic" {
  // A fixed linear congruential generator, so that each run reads the same inputs.
  let mut state = 0x2545f491UL
  let next = (bound : Int32) => {
    state = state * 6364136223846793005UL + 1442695040888963407UL
    ((state >> 33).to_int() & 0x7fffffff) % bound
  }
  for bytes in fuzz_fixtures {
    for _ in 0..<300 {
      let copy = Array::makei(bytes.length(), i => bytes[i])
      for _ in 0..<(1 + next(4)) {
        copy[8 + next(bytes.length() - 8)] = next(256).to_byte()
      }
      read_all(Bytes::from_array(copy))
    }
  }
}

///|
test "Truncated body: an instruction at the end of the bytes is a decode error" {
  // A module whose only body ends after `ref.null`, `block` or `if` with no immediate.
  for opcode in [b'\xd0', b'\x02', b'\x04'] {
    let bytes = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x03\x02\x01\x00\x0a\x04\x01\x02\x00" +
      Bytes::make(1, opcode)
    assert_true(refused(() => @binary.Module::parse(bytes)))
  }
}

///|
test "A vector count larger than the bytes left is a decode error, with no large allocation" {
  // A type section that claims 2^32 - 1 parameters.
  let bytes = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x07\x01\x60\xff\xff\xff\xff\x0f"
  assert_true(refused(() => @binary.Module::parse(bytes)))
}

///|
test "Multiple memories: two memories, or a memory index in a memarg, need multi-memory" {
  // (module (memory 1) (memory 1))
  let two = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x05\x05\x02\x00\x01\x00\x01"
  assert_eq(@binary.Module::parse(two).features(), [MultiMemory])
  // (module (memory 1)) with one memory needs no feature.
  let one = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x05\x03\x01\x00\x01"
  assert_eq(@binary.Module::parse(one).features(), [])
  // (module (import "env" "m" (memory 1)) (memory 1))
  let imported = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x02\x0a\x01\x03env\x01m\x02\x00\x01\x05\x03\x01\x00\x01"
  assert_eq(@binary.Module::parse(imported).features(), [MultiMemory])
  // (module (memory 1) (func i32.const 0 i32.load (memory 0) offset=0 drop)) with the memory index
  // encoded explicitly: the 0x40 flag of the alignment.
  let memarg = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x03\x02\x01\x00\x05\x03\x01\x00\x01\x0a\x0b\x01\x09\x00\x41\x00\x28\x42\x00\x00\x1a\x0b"
  assert_eq(@binary.Module::parse(memarg).features(), [MultiMemory])
}

///|
test "prepare: the start function becomes an export, memory 0 is exported and the start section goes" {
  let module_ = @binary.Module::parse(@fixtures.start_host())
  assert_eq(module_.start, Some(1))
  let prepared = @binary.Module::parse(module_.prepare())
  assert_eq(prepared.start, None)
  assert_false(prepared.sections.iter().any(s => s.id == 8))
  assert_true(
    prepared.exports.contains({
      name: @binary.start_export,
      kind: Func,
      index: 1,
    }),
  )
  assert_true(
    prepared.exports.contains({
      name: @binary.memory_export,
      kind: Memory,
      index: 0,
    }),
  )
  assert_eq(prepared.export_type("count"), module_.export_type("count"))
  assert_eq(prepared.features(), [])
}

///|
test "prepare: a module with no start and no memory is unchanged" {
  let bytes = @fixtures.add()
  assert_eq(@binary.Module::parse(bytes).prepare(), bytes)
}

///|
test "prepare refuses a module that exports a reserved name" {
  // (module (func (export "__moonrockz_extism_start")))
  let bytes = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x03\x02\x01\x00\x07\x1c\x01\x18\x5f\x5f\x6d\x6f\x6f\x6e\x72\x6f\x63\x6b\x7a\x5f\x65\x78\x74\x69\x73\x6d\x5f\x73\x74\x61\x72\x74\x00\x00\x0a\x04\x01\x02\x00\x0b"
  let refused = try @binary.Module::parse(bytes).prepare() catch {
    DecodeError(_, _) => true
  } noraise {
    _ => false
  }
  assert_true(refused)
}

///|
/// Modules whose indices, counts or sizes are the u32 value 0xffffffff, a number that does not fit
/// in an `Int32`. The parser runs before the engines validate the module, so each one must be a
/// decode error and not a negative index.
let large_u32_modules : Array[Bytes] = [
  // (type (func)) (import "a" "b" (func (type 0xffffffff)))
  b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x02\x0b\x01\x01a\x01b\x00\xff\xff\xff\xff\x0f",
  // (type (func)) (func (type 0)) (export "f" (func 0xffffffff)) (code (func))
   b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x03\x02\x01\x00\x07\x09\x01\x01f\x00\xff\xff\xff\xff\x0f\x0a\x04\x01\x02\x00\x0b",
  // An import section with a count of 0xffffffff.
   b"\x00\x61\x73\x6d\x01\x00\x00\x00\x02\x05\xff\xff\xff\xff\x0f",
  // A function section whose type index is 0xffffffff.
   b"\x00\x61\x73\x6d\x01\x00\x00\x00\x03\x06\x01\xff\xff\xff\xff\x0f",
  // A start section with the function 0xffffffff.
   b"\x00\x61\x73\x6d\x01\x00\x00\x00\x08\x05\xff\xff\xff\xff\x0f",
  // A data section with a count of 0xffffffff.
   b"\x00\x61\x73\x6d\x01\x00\x00\x00\x0b\x05\xff\xff\xff\xff\x0f",
  // A section size of 0x7fffffff, which overflows the end offset.
   b"\x00\x61\x73\x6d\x01\x00\x00\x00\x00\xff\xff\xff\xff\x07",
  // An import whose module name length is 0x7fffffff, which overflows the end offset.
   b"\x00\x61\x73\x6d\x01\x00\x00\x00\x02\x06\x01\xff\xff\xff\xff\x07",
  // A code section whose body size is 0x7fffffff.
   b"\x00\x61\x73\x6d\x01\x00\x00\x00\x0a\x06\x01\xff\xff\xff\xff\x07",
]

///|
test "an index, count or size of 0xffffffff is a decode error, not a panic" {
  for bytes in large_u32_modules {
    assert_true(refused(() => @binary.Module::parse(bytes)))
  }
}

///|
test "an index equal to its bound is a decode error, one below it is read" {
  // (type (func)) (import "a" "b" (func (type 1))): one type, so index 1 is out of bounds.
  let unknown = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x02\x07\x01\x01a\x01b\x00\x01"
  assert_true(refused(() => @binary.Module::parse(unknown)))
  // (type (func)) (import "a" "b" (func (type 0)))
  let known = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x02\x07\x01\x01a\x01b\x00\x00"
  assert_eq(@binary.Module::parse(known).imported_function_count(), 1)
}

///|
test "Parser fuzz: indices, counts and sizes of 0xffffffff are refused, never a panic" {
  for bytes in large_u32_modules {
    read_all(bytes)
    for length in 0..<=bytes.length() {
      read_all(bytes[0:length].to_owned())
    }
  }
}
