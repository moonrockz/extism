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
/// A deterministic random number source for the call sequences.
struct Rng {
  mut state : Int
}

///|
fn Rng::next(self : Rng, n : Int) -> Int {
  self.state = (self.state * 1103515245 + 12345) & 0x7fffffff
  self.state % n
}

///|
/// The initial size of kernel memory: 16 pages.
let kernel_end : Int64 = 16L * 65536L

///|
/// A 64-bit value to store: small numbers, and values near 2^63 and 2^64.
fn Rng::value(self : Rng) -> Int64 {
  match self.next(8) {
    0 => -1L
    1 => -2L
    2 => 0x7fffffffffffffffL
    3 => 0x7fffffffffffffffL + 1L
    4 => (self.next(0x7fffffff).to_int64() << 33) | self.next(0x7fffffff).to_int64()
    _ => self.next(256).to_int64()
  }
}

///|
/// An offset in a block, with the edges of a 64-byte block and of the 64-bit loads and stores.
fn Rng::offset(self : Rng) -> Int64 {
  match self.next(10) {
    0 => 56L
    1 => 57L
    2 => 63L
    3 => 64L
    _ => self.next(20).to_int64()
  }
}

///|
/// The next call of a sequence: allocate, store, load, free, reuse, input, output, error, reset and out of
/// memory. The calls refer to the handles that upstream's `alloc` gave, to plausible guesses, to the
/// edge of the root record at offset 64, and to the end of kernel memory.
fn Rng::call(self : Rng, handles : Array[Int64]) -> (String, Array[Int64]) {
  let pick = () => {
    match self.next(10) {
      0 => self.next(200000).to_int64()
      1 => [56L, 57L, 63L, 64L, 65L][self.next(5)]
      2 => kernel_end - 8L + self.next(16).to_int64()
      _ =>
        if handles.length() > 0 {
          handles[self.next(handles.length())]
        } else {
          77L
        }
    }
  }
  match self.next(14) {
    0 | 1 => {
      let size = if self.next(5) != 0 {
        self.next(300)
      } else {
        self.next(200000)
      }
      ("alloc", [size.to_int64()])
    }
    2 => ("free", [pick()])
    3 => ("length", [pick()])
    4 => ("length_unsafe", [pick()])
    5 => ("store_u8", [pick() + self.offset(), self.next(256).to_int64()])
    6 => ("store_u64", [pick() + self.offset(), self.value()])
    7 => ("load_u64", [pick() + self.offset()])
    8 => ("load_u8", [pick() + self.offset()])
    9 => ("input_set", [pick(), self.next(80).to_int64()])
    10 =>
      if self.next(2) == 0 {
        ("input_load_u8", [self.next(90).to_int64()])
      } else {
        ("input_load_u64", [self.next(90).to_int64()])
      }
    11 => ("error_set", [if self.next(3) != 0 { pick() } else { 0L }])
    12 =>
      if self.next(10) == 0 {
        ("reset", [])
      } else {
        ("output_set", [pick(), self.next(30).to_int64()])
      }
    _ =>
      (
        [
          "input_length", "input_offset", "output_length", "output_offset", "error_get",
          "memory_bytes",
        ][self.next(6)],
        [],
      )
  }
}

///|
/// A kernel result for a test message.
fn shown(result : Int64?) -> String {
  match result {
    Some(value) => value.to_string()
    None => "a trap"
  }
}

///|
/// A kernel with the calls `calls` run on it.
fn Kernel::replay(
  bytes : Bytes,
  ceiling : Int32,
  calls : Array[(String, Array[Int64])],
) -> Kernel raise {
  let kernel = Kernel::start(bytes, ceiling)
  for call in calls {
    kernel.run(call.0, call.1) |> ignore
  }
  kernel
}

///|
/// Runs a generated sequence of `steps` calls on both kernels. Every result must be the same. Where
/// upstream traps, the Zig kernel traps too or gives 0, as the out-of-bounds requirement says; then both
/// kernels start again with the calls before the trap, and the sequence goes on. Gives the number of
/// calls and the number of upstream traps.
fn differential_sequence(
  seed : Int,
  steps : Int,
  ceiling~ : Int32 = 64,
) -> (Int, Int) raise {
  let rng = { state: seed }
  let mut ours = Kernel::start(@kernel.bytes(), ceiling)
  let mut theirs = Kernel::start(@upstream.upstream_kernel(), ceiling)
  let handles : Array[Int64] = []
  let done : Array[(String, Array[Int64])] = []
  let mut traps = 0
  for step in 0..<steps {
    let (name, args) = rng.call(handles)
    let expected = theirs.run(name, args)
    let actual = ours.run(name, args)
    match expected {
      Some(value) => {
        assert_eq(
          actual,
          expected,
          msg="seed \{seed}: \{name} \{args.map(a => a.to_string()).join(", ")} at step \{step}: ours \{shown(actual)}, upstream \{shown(expected)}",
        )
        done.push((name, args))
        if name == "alloc" && value != 0L {
          handles.push(value)
        }
      }
      None => {
        traps += 1
        assert_true(
          actual is None || actual is Some(0L),
          msg="seed \{seed}: \{name} \{args.map(a => a.to_string()).join(", ")} at step \{step}: upstream traps, ours gives \{shown(actual)}",
        )
        ours = Kernel::replay(@kernel.bytes(), ceiling, done)
        theirs = Kernel::replay(@upstream.upstream_kernel(), ceiling, done)
      }
    }
  }
  // The bytes at each live handle are the same.
  for handle in handles {
    let length = theirs.run("length", [handle]).unwrap_or(0L)
    assert_eq(ours.run("length", [handle]), Some(length))
    for i = 0L; i < length && i < 72L; i = i + 1L {
      assert_eq(
        ours.run("load_u8", [handle + i]),
        theirs.run("load_u8", [handle + i]),
        msg="seed \{seed}: byte \{i} of handle \{handle}, length \{length}",
      )
    }
  }
  (steps, traps)
}

///|
/// Runs `calls` on both kernels; every result must be the same until upstream traps.
fn differential(
  calls : Array[(String, Array[Int64])],
  ceiling~ : Int32 = 64,
) -> Int32 raise {
  let ours = Kernel::start(@kernel.bytes(), ceiling)
  let theirs = Kernel::start(@upstream.upstream_kernel(), ceiling)
  let mut compared = 0
  for call in calls {
    let (name, args) = call
    guard theirs.run(name, args) is Some(expected) else { break }
    let actual = ours.run(name, args)
    assert_eq(actual, Some(expected), msg="\{name} after \{compared} calls")
    compared += 1
  }
  compared
}

///|
test "Differential call sequence: the Zig kernel gives the upstream results" {
  let mut total = 0
  let mut traps = 0
  for seed in 1..<=60 {
    let (calls, trapped) = differential_sequence(seed, 200)
    total += calls
    traps += trapped
  }
  assert_eq(total, 12000)
  // The sequences reach the end of kernel memory, where upstream traps.
  assert_true(traps > 0)
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
test "Store at the edge of the root record: stores that end at 63 change nothing, at 64 they run, as upstream" {
  let calls = [
    ("alloc", [100L]),
    ("output_set", [77L, 5L]),
    // p + n - 1 is 63: refused.
    ("store_u8", [63L, 0xffL]),
    ("store_u64", [56L, -1L]),
    ("output_length", []),
    ("load_u64", [56L]),
    // p + n - 1 is 64: the store runs, into the last byte of the root record.
    ("store_u8", [64L, 0x01L]),
    ("store_u64", [57L, 0x0102030405060708L]),
    ("load_u64", [57L]),
    ("load_u8", [64L]),
    ("output_offset", []),
    ("output_length", []),
    ("alloc", [8L]),
    ("length", [77L]),
  ]
  assert_eq(differential(calls), calls.length())
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
