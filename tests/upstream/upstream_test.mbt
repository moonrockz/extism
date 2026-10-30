///|
test "Successful call: count_vowels of hello world gives a count of 3" {
  let manifest = @extism.Manifest::new(@upstream.count_vowels()).wasi(
    @wasi.Sandbox::new(),
  )
  let plugin = @extism.Plugin::load(manifest)
  let output = plugin.call(
    @extism.ExportName::parse("count_vowels"),
    b"hello world",
  )
  let reply = @json.parse(@utf8.decode(output))
  guard reply is { "count": Number(count, ..), .. } else {
    fail("no count in \{reply.stringify()}")
  }
  assert_eq(count, 3.0)
  // A second call on the same plugin.
  let again = @json.parse(
    @utf8.decode(
      plugin.call(@extism.ExportName::parse("count_vowels"), b"aeiou"),
    ),
  )
  assert_true(again is { "count": Number(5.0, ..), .. })
}

///|
/// One kernel instance, for a differential run.
struct Kernel {
  instance : @engine.Instance
}

///|
fn Kernel::start(bytes : Bytes, ceiling : Int32) -> Kernel raise {
  let module_ = @engine.Engine::default().compile(bytes)
  {
    instance: module_.instantiate(
      @engine.Imports::new(),
      memory_ceiling=@engine.PageCount::parse(ceiling),
    ),
  }
}

///|
/// The result of a kernel call as one number, or `None` when the call traps.
fn Kernel::run(self : Kernel, name : String, args : Array[Int64]) -> Int64? {
  let function = @kernel.KernelFunction::from_name(name).unwrap()
  let values = args.mapi((i, a) => {
    match function.params()[i] {
      I32 => @engine.Value::I32(a.to_int())
      I64 => I64(a)
    }
  })
  let results = self.instance.call(name, values) catch { _ => return None }
  match results {
    [I64(v)] => Some(v)
    [I32(v)] => Some(v.to_int64())
    _ => Some(0L)
  }
}

///|
/// A deterministic sequence of kernel calls: allocate, store, load, free, reuse, input, output,
/// error, reset and out of memory.
fn sequence(seed : Int32, steps : Int32) -> Array[(String, Array[Int64])] {
  let mut state = seed
  let next = (n : Int32) => {
    state = (state * 1103515245 + 12345) & 0x7fffffff
    state % n
  }
  let handles : Array[Int64] = []
  let pick = () => {
    if handles.length() > 0 && next(4) != 0 {
      handles[next(handles.length())]
    } else {
      next(200000).to_int64()
    }
  }
  let calls = []
  for _ in 0..<steps {
    let call = match next(12) {
      0 | 1 => {
        let size = if next(5) != 0 { next(300) } else { next(200000) }
        // The handle of a fresh allocation is the bump position; record a guess for later calls.
        ("alloc", [size.to_int64()])
      }
      2 => ("free", [pick()])
      3 => ("length", [pick()])
      4 => ("length_unsafe", [pick()])
      5 => ("store_u8", [pick() + next(20).to_int64(), next(256).to_int64()])
      6 => ("load_u64", [pick() + next(20).to_int64()])
      7 => ("input_set", [pick(), next(30).to_int64()])
      8 => ("input_load_u8", [next(40).to_int64()])
      9 => ("error_set", [if next(3) != 0 { pick() } else { 0L }])
      10 =>
        if next(10) == 0 {
          ("reset", [])
        } else {
          ("output_set", [pick(), next(30).to_int64()])
        }
      _ =>
        (
          [
            "input_length", "input_offset", "output_length", "output_offset", "error_get",
            "memory_bytes",
          ][next(6)],
          [],
        )
    }
    calls.push(call)
    if call.0 == "alloc" {
      // Later calls refer to a plausible handle: 77 is the first handle of a fresh kernel.
      handles.push(77L + next(1000).to_int64())
    }
  }
  calls
}

///|
/// Runs `calls` on both kernels; every result must be the same until upstream traps.
fn differential(
  calls : Array[(String, Array[Int64])],
  ceiling~ : Int32 = 64,
) -> Int32 raise {
  let ours = Kernel::start(@kernel.bytes(), ceiling)
  let theirs = Kernel::start(@upstream.upstream_kernel(), ceiling)
  let live : Array[Int64] = []
  let mut compared = 0
  for call in calls {
    let (name, args) = call
    guard theirs.run(name, args) is Some(expected) else { break }
    let actual = ours.run(name, args)
    assert_eq(actual, Some(expected), msg="\{name} after \{compared} calls")
    compared += 1
    if name == "alloc" && expected != 0L {
      live.push(expected)
    }
  }
  // The bytes at each live handle are the same.
  for handle in live {
    let length = theirs.run("length", [handle]).unwrap_or(0L)
    assert_eq(ours.run("length", [handle]), Some(length))
    for i = 0L; i < length && i < 64L; i = i + 1L {
      assert_eq(
        ours.run("load_u8", [handle + i]),
        theirs.run("load_u8", [handle + i]),
      )
    }
  }
  compared
}

///|
test "Differential call sequence: the Zig kernel gives the upstream results" {
  let mut total = 0
  for seed in 1..<=40 {
    total += differential(sequence(seed, 150))
  }
  assert_true(total > 3000)
}

///|
test "First handle: alloc(10) on a new kernel gives 77, as upstream" {
  assert_eq(
    differential([
      ("alloc", [10]),
      ("alloc", [5]),
      ("length", [77]),
      ("length", [99]),
    ]),
    4,
  )
  let ours = Kernel::start(@kernel.bytes(), 64)
  assert_eq(ours.run("alloc", [10]), Some(77L))
}

///|
test "Freed handle: length of a freed block is 0, as upstream" {
  assert_eq(
    differential([
      ("alloc", [10]),
      ("free", [77]),
      ("length", [77]),
      ("alloc", [5]),
    ]),
    4,
  )
}

///|
test "Kernel memory at its ceiling: alloc gives 0 and earlier handles keep their bytes" {
  let calls = [
    ("alloc", [4L]),
    ("store_u8", [77L, 0x6bL]),
    ("alloc", [2_000_000L]),
    ("load_u8", [77L]),
    ("length", [77L]),
  ]
  assert_eq(differential(calls, ceiling=17), 5)
  let ours = Kernel::start(@kernel.bytes(), 17)
  ours.run("alloc", [4]) |> ignore
  ours.run("store_u8", [77, 0x6b]) |> ignore
  assert_eq(ours.run("alloc", [2_000_000]), Some(0L))
  assert_eq(ours.run("load_u8", [77]), Some(0x6bL))
  assert_true(ours.instance.take_refused_grow())
}

///|
test "Load past the end: load_u64 4 bytes before the end gives 0" {
  let end = 16L * 65536L
  assert_eq(differential([("alloc", [1]), ("load_u64", [end - 4L])]), 2)
  assert_eq(
    Kernel::start(@kernel.bytes(), 64).run("load_u64", [end - 4L]),
    Some(0L),
  )
}

///|
test "Load at the memory size: the Zig kernel gives 0 where upstream traps" {
  let end = 16L * 65536L
  assert_eq(
    Kernel::start(@upstream.upstream_kernel(), 64).run("load_u8", [end]),
    None,
  )
  assert_eq(Kernel::start(@kernel.bytes(), 64).run("load_u8", [end]), Some(0L))
}

///|
test "Store into the root record: the next alloc gives the upstream handle" {
  assert_eq(
    differential([
      ("alloc", [3]),
      ("store_u8", [1, 0]),
      ("store_u8", [9, 0xff]),
      ("alloc", [3]),
    ]),
    4,
  )
}

///|
test "Input past its length: input_load_u8 at 3 of a 3-byte input gives 0" {
  let calls = [
    ("alloc", [3L]),
    ("store_u8", [77L, 0x61L]),
    ("input_set", [77L, 3L]),
    ("input_load_u8", [0L]),
    ("input_load_u8", [3L]),
  ]
  assert_eq(differential(calls), 5)
  let ours = Kernel::start(@kernel.bytes(), 64)
  for call in calls[:3] {
    ours.run(call.0, call.1) |> ignore
  }
  assert_eq(ours.run("input_load_u8", [3]), Some(0L))
}
