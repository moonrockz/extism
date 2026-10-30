///|
/// A guest memory over plain bytes, for the tests.
struct Plain {
  bytes : FixedArray[Byte]
}

///|
impl @wasi.GuestMemory for Plain with fn size(self) {
  self.bytes.length().to_int64()
}

///|
impl @wasi.GuestMemory for Plain with fn read(self, offset, length) {
  guard offset >= 0L &&
    length >= 0 &&
    offset + length.to_int64() <= self.bytes.length().to_int64() else {
    raise OutOfBounds(offset, length)
  }
  Bytes::makei(length, i => self.bytes[offset.to_int() + i])
}

///|
impl @wasi.GuestMemory for Plain with fn write(self, offset, bytes) {
  guard offset >= 0L &&
    offset + bytes.length().to_int64() <= self.bytes.length().to_int64() else {
    raise OutOfBounds(offset, bytes.length())
  }
  for i, byte in bytes {
    self.bytes[offset.to_int() + i] = byte
  }
}

///|
fn plain() -> Plain {
  { bytes: FixedArray::make(1024, b'\xaa'), }
}

///|
fn u32_at(memory : Plain, at : Int32) -> Int32 {
  memory.bytes[at].to_int() |
  (memory.bytes[at + 1].to_int() << 8) |
  (memory.bytes[at + 2].to_int() << 16) |
  (memory.bytes[at + 3].to_int() << 24)
}

///|
fn u64_at(memory : Plain, at : Int32) -> UInt64 {
  let mut value = 0UL
  for i = 7; i >= 0; i = i - 1 {
    value = (value << 8) | memory.bytes[at + i].to_uint64()
  }
  value
}

///|
fn put(memory : Plain, at : Int32, bytes : Bytes) -> Unit {
  for i, byte in bytes {
    memory.bytes[at + i] = byte
  }
}

///|
fn put_u32(memory : Plain, at : Int32, value : Int32) -> Unit {
  for i in 0..<4 {
    memory.bytes[at + i] = (value >> (8 * i)).to_byte()
  }
}

///|
fn call(
  sandbox : @wasi.Sandbox,
  function : @wasi.Function,
  memory : Plain,
  args : Array[Int64],
) -> @wasi.Outcome {
  sandbox.call(function, memory, args)
}

///|
test "Program reads its arguments: empty lists and success" {
  let memory = plain()
  let sandbox = @wasi.Sandbox::new()
  assert_eq(call(sandbox, ArgsSizesGet, memory, [0, 4]), Return(Success))
  assert_eq(u32_at(memory, 0), 0)
  assert_eq(u32_at(memory, 4), 0)
  assert_eq(call(sandbox, EnvironSizesGet, memory, [8, 12]), Return(Success))
  assert_eq(u32_at(memory, 8), 0)
  assert_eq(u32_at(memory, 12), 0)
  assert_eq(call(sandbox, ArgsGet, memory, [100, 200]), Return(Success))
  assert_eq(call(sandbox, EnvironGet, memory, [100, 200]), Return(Success))
  assert_eq(memory.bytes[100], b'\xaa')
}

///|
test "Program reads stdin: 0 bytes, end of file" {
  let memory = plain()
  put_u32(memory, 16, 64)
  put_u32(memory, 20, 32)
  assert_eq(
    call(@wasi.Sandbox::new(), FdRead, memory, [0, 16, 1, 40]),
    Return(Success),
  )
  assert_eq(u32_at(memory, 40), 0)
}

///|
test "Plugin prints: the sinks get the bytes and all bytes are written" {
  let out = @buffer.Buffer()
  let err = @buffer.Buffer()
  let sandbox = @wasi.Sandbox::new()
    .stdout(bytes => out.write_bytes(bytes))
    .stderr(bytes => err.write_bytes(bytes))
  let memory = plain()
  put(memory, 200, b"hello")
  put(memory, 300, b"oops")
  // Two iovecs for stdout: "hel" and "lo".
  put_u32(memory, 0, 200)
  put_u32(memory, 4, 3)
  put_u32(memory, 8, 203)
  put_u32(memory, 12, 2)
  assert_eq(call(sandbox, FdWrite, memory, [1, 0, 2, 100]), Return(Success))
  assert_eq(u32_at(memory, 100), 5)
  put_u32(memory, 16, 300)
  put_u32(memory, 20, 4)
  assert_eq(call(sandbox, FdWrite, memory, [2, 16, 1, 104]), Return(Success))
  assert_eq(u32_at(memory, 104), 4)
  assert_eq(out.to_bytes(), b"hello")
  assert_eq(err.to_bytes(), b"oops")
}

///|
test "without a sink the bytes are discarded and reported as written" {
  let memory = plain()
  put_u32(memory, 0, 200)
  put_u32(memory, 4, 7)
  assert_eq(
    call(@wasi.Sandbox::new(), FdWrite, memory, [1, 0, 1, 100]),
    Return(Success),
  )
  assert_eq(u32_at(memory, 100), 7)
}

///|
test "Deterministic clock: the plugin reads 42" {
  let sandbox = @wasi.Sandbox::new().clock({
    time: _ => 42UL,
    resolution: _ => 1UL,
  })
  let memory = plain()
  assert_eq(call(sandbox, ClockTimeGet, memory, [1, 0, 8]), Return(Success))
  assert_eq(u64_at(memory, 8), 42UL)
  assert_eq(call(sandbox, ClockResGet, memory, [0, 16]), Return(Success))
  assert_eq(u64_at(memory, 16), 1UL)
  assert_eq(call(sandbox, ClockTimeGet, memory, [9, 0, 8]), Return(Inval))
}

///|
test "without a clock the clock functions are not capable" {
  let memory = plain()
  assert_eq(
    call(@wasi.Sandbox::new(), ClockTimeGet, memory, [0, 0, 8]),
    Return(Notcapable),
  )
  assert_eq(
    call(@wasi.Sandbox::new(), ClockResGet, memory, [0, 8]),
    Return(Notcapable),
  )
}

///|
test "No random source: ENOTCAPABLE and the buffer is not changed" {
  let memory = plain()
  assert_eq(
    call(@wasi.Sandbox::new(), RandomGet, memory, [64, 16]),
    Return(Notcapable),
  )
  assert_true(memory.bytes[64:80].iter().all(b => b == b'\xaa'))
  assert_eq(@wasi.Errno::Notcapable.code(), 76)
}

///|
test "a random source fills the buffer" {
  let sandbox = @wasi.Sandbox::new().random(n => Bytes::make(n, b'\x07'))
  let memory = plain()
  assert_eq(call(sandbox, RandomGet, memory, [64, 4]), Return(Success))
  assert_eq(memory.bytes[64:68].iter().collect(), [
    b'\x07', b'\x07', b'\x07', b'\x07',
  ])
}

///|
test "Preopen scan: fd_prestat_get on fd 3 is EBADF" {
  assert_eq(
    call(@wasi.Sandbox::new(), FdPrestatGet, plain(), [3, 0]),
    Return(Badf),
  )
  assert_eq(@wasi.Errno::Badf.code(), 8)
}

///|
test "Open a file: path_open with fd 3 is EBADF" {
  assert_eq(
    call(@wasi.Sandbox::new(), PathOpen, plain(), [3, 0, 0, 4, 0, 0, 0, 0, 100]),
    Return(Badf),
  )
}

///|
test "Write to stdin: ENOTCAPABLE" {
  assert_eq(
    call(@wasi.Sandbox::new(), FdWrite, plain(), [0, 0, 0, 100]),
    Return(Notcapable),
  )
}

///|
test "Plugin that imports an unusual function: path_symlink returns an error code" {
  assert_eq(
    call(@wasi.Sandbox::new(), PathSymlink, plain(), [0, 0, 3, 0, 0]),
    Return(Notcapable),
  )
  assert_eq(
    call(@wasi.Sandbox::new(), PathSymlink, plain(), [0, 0, 7, 0, 0]),
    Return(Notcapable),
  )
}

///|
test "Plugin exits with code 3, and with code 0" {
  assert_eq(call(@wasi.Sandbox::new(), ProcExit, plain(), [3]), Exit(3))
  assert_eq(call(@wasi.Sandbox::new(), ProcExit, plain(), [0]), Exit(0))
}

///|
test "Start-up checks of stdout: a character device with the fd_write right" {
  let memory = plain()
  assert_eq(
    call(@wasi.Sandbox::new(), FdFdstatGet, memory, [1, 0]),
    Return(Success),
  )
  assert_eq(memory.bytes[0], b'\x02')
  assert_eq(u64_at(memory, 8), 1UL << 6)
  assert_eq(u64_at(memory, 16), 0UL)
  assert_eq(
    call(@wasi.Sandbox::new(), FdFdstatGet, memory, [0, 32]),
    Return(Success),
  )
  assert_eq(u64_at(memory, 40), 1UL << 1)
  assert_eq(
    call(@wasi.Sandbox::new(), FdFilestatGet, memory, [2, 64]),
    Return(Success),
  )
  assert_eq(memory.bytes[64 + 16], b'\x02')
  assert_eq(u64_at(memory, 64 + 32), 0UL)
  assert_eq(
    call(@wasi.Sandbox::new(), FdFdstatGet, memory, [5, 0]),
    Return(Badf),
  )
}

///|
test "an address outside the memory is EFAULT" {
  assert_eq(
    call(@wasi.Sandbox::new(), ArgsSizesGet, plain(), [1022, 0]),
    Return(Fault),
  )
}

///|
test "every other function and operation is not capable" {
  let memory = plain()
  for
    function in [
      @wasi.Function::PollOneoff,
      SchedYield,
      ProcRaise,
      FdClose,
      FdSeek,
      PathUnlinkFile,
      SockAccept,
    ] {
    let args = function.params().map(_ => 0L)
    assert_eq(
      call(@wasi.Sandbox::new(), function, memory, args),
      Return(Notcapable),
    )
  }
  assert_eq(
    call(@wasi.Sandbox::new(), FdRead, memory, [1, 0, 0, 0]),
    Return(Notcapable),
  )
}

///|
test "the table has the preview 1 signatures" {
  assert_eq(@wasi.Function::all().length(), 46)
  assert_eq(@wasi.Function::FdWrite.params(), [I32, I32, I32, I32])
  assert_eq(@wasi.Function::ClockTimeGet.params(), [I32, I64, I32])
  assert_eq(@wasi.Function::PathOpen.params(), [
    I32,
    I32,
    I32,
    I32,
    I32,
    I64,
    I64,
    I32,
    I32,
  ])
  assert_eq(@wasi.Function::ProcExit.results(), [])
  assert_eq(@wasi.Function::SchedYield.params(), [])
  assert_eq(@wasi.Function::SchedYield.results(), [I32])
  assert_eq(@wasi.import_namespace, "wasi_snapshot_preview1")
}
