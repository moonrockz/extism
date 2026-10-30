///|
/// A WASI errno that the sandbox gives.
pub(all) enum Errno {
  Success
  /// 8: the fd is not open; the sandbox has only fds 0, 1 and 2.
  Badf
  /// 21: an address that the guest gave is outside its memory.
  Fault
  /// 28: an argument is not valid, for example an unknown clock id.
  Inval
  /// 76: the sandbox does not give the guest this capability.
  Notcapable
} derive(Eq, Debug)

///|
pub extend Errno with Eq::{equal, not_equal}

///|
pub extend Errno with @debug.Debug::{to_repr}

///|
/// The number of the errno.
pub fn Errno::code(self : Errno) -> Int32 {
  match self {
    Success => 0
    Badf => 8
    Fault => 21
    Inval => 28
    Notcapable => 76
  }
}

///|
/// A WASI clock.
pub(all) enum ClockId {
  Realtime
  Monotonic
  ProcessCputime
  ThreadCputime
} derive(Eq, Debug)

///|
pub extend ClockId with Eq::{equal, not_equal}

///|
pub extend ClockId with @debug.Debug::{to_repr}

///|
fn ClockId::parse(id : Int64) -> ClockId? {
  match id {
    0L => Some(Realtime)
    1L => Some(Monotonic)
    2L => Some(ProcessCputime)
    3L => Some(ThreadCputime)
    _ => None
  }
}

///|
/// A clock source of the embedder: the time and the resolution of each clock, in nanoseconds.
pub(all) struct Clock {
  time : (ClockId) -> UInt64
  resolution : (ClockId) -> UInt64
}

///|
/// The result of a sandbox call.
pub(all) enum Outcome {
  /// The function returns this errno to the guest.
  Return(Errno)
  /// `proc_exit` with this code: the call of the guest ends.
  Exit(Int32)
} derive(Eq, Debug)

///|
pub extend Outcome with Eq::{equal, not_equal}

///|
pub extend Outcome with @debug.Debug::{to_repr}

///|
/// A sink bound that breaks its rule: the bytes and the rule.
pub(all) suberror SinkBoundError {
  SinkBoundError(Int, String)
} derive(Eq, Debug)

///|
pub extend SinkBoundError with Eq::{equal, not_equal}

///|
pub extend SinkBoundError with @debug.Debug::{to_repr}

///|
/// The most bytes that one `fd_write` gives a sink: 1 byte to 16 MiB. The bound applies to each call;
/// a guest that writes in a loop makes many calls, so the embedder's sink bounds the total itself, for
/// example with a tail of the last bytes.
pub struct SinkBound {
  priv bytes : Int
} derive(Eq, Debug)

///|
pub extend SinkBound with Eq::{equal, not_equal}

///|
pub extend SinkBound with @debug.Debug::{to_repr}

///|
/// The largest sink bound: 16 MiB.
let max_sink_bound : Int = 16 * 1024 * 1024

///|
/// A sink bound of `bytes` bytes, from 1 to 16 MiB.
pub fn SinkBound::parse(bytes : Int) -> SinkBound raise SinkBoundError {
  guard bytes >= 1 && bytes <= max_sink_bound else {
    raise SinkBoundError(
      bytes,
      "a sink bound is from 1 byte to \{max_sink_bound} bytes",
    )
  }
  { bytes, }
}

///|
/// The default sink bound: 1 MiB.
pub fn SinkBound::default() -> SinkBound {
  { bytes: 1024 * 1024 }
}

///|
pub fn SinkBound::bytes(self : SinkBound) -> Int {
  self.bytes
}

///|
/// A sink of the embedder and its bound.
priv struct Sink {
  write : (BytesView) -> Unit
  bound : SinkBound
}

///|
/// The WASI preview 1 sandbox of a plugin: no preopens, empty arguments, environment and stdin, clocks
/// and random bytes from sources that the embedder gives, and stdout and stderr to sinks that the
/// embedder gives. Every other function returns `ENOTCAPABLE` or `EBADF`. The builder steps give a new
/// sandbox.
pub struct Sandbox {
  priv clock : Clock?
  priv random : ((Int32) -> Bytes)?
  priv stdout : Sink?
  priv stderr : Sink?
}

///|
/// A sandbox with no clock, no random source and no sinks.
pub fn Sandbox::new() -> Sandbox {
  { clock: None, random: None, stdout: None, stderr: None, }
}

///|
/// The sandbox with `clock` as its clock source.
pub fn Sandbox::clock(self : Sandbox, clock : Clock) -> Sandbox {
  { ..self, clock: Some(clock), }
}

///|
/// The sandbox with a random source, which gives the number of bytes that it is asked for.
pub fn Sandbox::random(self : Sandbox, source : (Int32) -> Bytes) -> Sandbox {
  { ..self, random: Some(source), }
}

///|
/// The sandbox with a sink for the bytes that the guest writes to fd 1. One `fd_write` gives the sink
/// at most `bound` bytes, one iovec at a time; it writes the first `bound` bytes and reports them, as a
/// POSIX `write` that writes part of its bytes.
pub fn Sandbox::stdout(
  self : Sandbox,
  sink : (BytesView) -> Unit,
  bound~ : SinkBound = SinkBound::default(),
) -> Sandbox {
  { ..self, stdout: Some({ write: sink, bound }) }
}

///|
/// The sandbox with a sink for the bytes that the guest writes to fd 2, with the rules of `stdout`.
pub fn Sandbox::stderr(
  self : Sandbox,
  sink : (BytesView) -> Unit,
  bound~ : SinkBound = SinkBound::default(),
) -> Sandbox {
  { ..self, stderr: Some({ write: sink, bound }) }
}

///|
/// A file type: a character device.
let character_device : Int32 = 2

///|
/// The `fd_read` right.
let right_fd_read : UInt64 = 1UL << 1

///|
/// The `fd_write` right.
let right_fd_write : UInt64 = 1UL << 6

///|
/// The indices of the fd arguments of a function, in its core signature.
fn fd_arguments(function : Function) -> Array[Int32] {
  match function {
    FdRenumber => [0, 1]
    PathSymlink => [2]
    PathLink => [0, 4]
    PathRename => [0, 3]
    _ =>
      if function.name().has_prefix("fd_") ||
        function.name().has_prefix("path_") ||
        function.name().has_prefix("sock_") {
        [0]
      } else {
        []
      }
  }
}

///|
fn standard(fd : Int64) -> Bool {
  fd >= 0L && fd <= 2L
}

///|
/// An argument as an unsigned 32-bit number: an address, a length or an fd.
fn unsigned(value : Int64) -> Int64 {
  value & 0xffffffffL
}

///|
/// Runs the preview 1 function `function` with the arguments `args` (an `i32` as its value, an `i64` as
/// its value) on the guest memory `memory`.
pub fn[M : GuestMemory] Sandbox::call(
  self : Sandbox,
  function : Function,
  memory : M,
  args : Array[Int64],
) -> Outcome {
  if args.length() != function.params().length() {
    return Return(Inval)
  }
  let arg = (i : Int32) => unsigned(args[i])
  if fd_arguments(function).iter().any(i => !standard(arg(i))) {
    return Return(Badf)
  }
  let errno = self.answer(function, memory, arg) catch {
    OutOfBounds(_, _) => Fault
  }
  match function {
    ProcExit => Exit(args[0].to_int())
    _ => Return(errno)
  }
}

///|
fn[M : GuestMemory] Sandbox::answer(
  self : Sandbox,
  function : Function,
  memory : M,
  arg : (Int32) -> Int64,
) -> Errno raise GuestMemoryError {
  match function {
    ArgsSizesGet | EnvironSizesGet => {
      write_u32(memory, arg(0), 0L)
      write_u32(memory, arg(1), 0L)
      Success
    }
    ArgsGet | EnvironGet => Success
    FdRead =>
      if arg(0) == 0L {
        write_u32(memory, arg(3), 0L)
        Success
      } else {
        Notcapable
      }
    FdWrite => {
      let sink = match arg(0) {
        1L => Some(self.stdout)
        2L => Some(self.stderr)
        _ => None
      }
      guard sink is Some(sink) else { return Notcapable }
      // Every range is checked before any byte goes to the sink.
      guard iovecs(memory, arg(1), arg(2)) is Some(pairs) else { return Inval }
      guard inside(memory, arg(3), 4L) else {
        raise OutOfBounds(arg(3), 4)
      }
      let bound = match sink {
        Some(sink) => sink.bound.bytes().to_int64()
        None => SinkBound::default().bytes().to_int64()
      }
      let mut written = 0L
      for pair in pairs {
        let (buffer, length) = pair
        let part = @cmp.minimum(length, bound - written)
        if part > 0L && sink is Some(sink) {
          (sink.write)(memory.read(buffer, part.to_int()))
        }
        written = written + part
      }
      write_u32(memory, arg(3), written)
      Success
    }
    FdFdstatGet => {
      let rights = if arg(0) == 0L { right_fd_read } else { right_fd_write }
      let stat = Bytes::makei(24, i => {
        if i == 0 {
          character_device.to_byte()
        } else {
          b'\x00'
        }
      })
      memory.write(arg(1), stat)
      write_u64(memory, arg(1) + 8L, rights)
      write_u64(memory, arg(1) + 16L, 0UL)
      Success
    }
    FdFilestatGet => {
      let stat = Bytes::makei(64, i => {
        if i == 16 {
          character_device.to_byte()
        } else {
          b'\x00'
        }
      })
      memory.write(arg(1), stat)
      Success
    }
    ClockResGet | ClockTimeGet => {
      guard self.clock is Some(clock) else { return Notcapable }
      guard ClockId::parse(arg(0)) is Some(id) else { return Inval }
      if function is ClockResGet {
        write_u64(memory, arg(1), (clock.resolution)(id))
      } else {
        write_u64(memory, arg(2), (clock.time)(id))
      }
      Success
    }
    RandomGet => {
      guard self.random is Some(source) else { return Notcapable }
      // The range is checked before the embedder's source runs; a length of 2^31 or more is larger
      // than a guest memory that the engines give.
      guard arg(1) < 0x80000000L && inside(memory, arg(0), arg(1)) else {
        raise OutOfBounds(arg(0), arg(1).to_int())
      }
      let length = arg(1).to_int()
      let bytes = source(length)
      guard bytes.length() == length else { return Notcapable }
      memory.write(arg(0), bytes)
      Success
    }
    ProcExit => Success
    _ => Notcapable
  }
}
