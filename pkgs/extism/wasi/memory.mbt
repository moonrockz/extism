///|
/// A guest memory access outside the memory: the offset and the length.
pub(all) suberror GuestMemoryError {
  OutOfBounds(Int64, Int32)
} derive(Eq, Debug)

///|
pub extend GuestMemoryError with Eq::{equal, not_equal}

///|
pub extend GuestMemoryError with @debug.Debug::{to_repr}

///|
/// The linear memory of a guest, as the sandbox sees it. The engine implements it for the memory of an
/// instance; a test can implement it over plain bytes. An access outside the memory raises
/// `OutOfBounds` and reads or writes nothing.
pub(open) trait GuestMemory {
  /// The size of the memory in bytes.
  fn size(Self) -> Int64
  /// The `length` bytes at `offset`.
  fn read(Self, Int64, Int32) -> Bytes raise GuestMemoryError
  /// Writes the bytes at `offset`.
  fn write(Self, Int64, BytesView) -> Unit raise GuestMemoryError
}

///|
fn[M : GuestMemory] read_u32(
  memory : M,
  at : Int64,
) -> Int64 raise GuestMemoryError {
  let bytes = memory.read(at, 4)
  let value = bytes[0].to_int64() |
    (bytes[1].to_int64() << 8) |
    (bytes[2].to_int64() << 16) |
    (bytes[3].to_int64() << 24)
  value
}

///|
fn little(value : UInt64, count : Int32) -> Bytes {
  Bytes::makei(count, i => (value >> (8 * i)).to_byte())
}

///|
fn[M : GuestMemory] write_u32(
  memory : M,
  at : Int64,
  value : Int64,
) -> Unit raise GuestMemoryError {
  memory.write(at, little(value.reinterpret_as_uint64(), 4))
}

///|
fn[M : GuestMemory] write_u64(
  memory : M,
  at : Int64,
  value : UInt64,
) -> Unit raise GuestMemoryError {
  memory.write(at, little(value, 8))
}

///|
/// The `(buffer, length)` pairs of an iovec array.
fn[M : GuestMemory] iovecs(
  memory : M,
  at : Int64,
  count : Int64,
) -> Array[(Int64, Int32)] raise GuestMemoryError {
  let pairs = []
  for i = 0L; i < count; i = i + 1L {
    let entry = at + 8L * i
    pairs.push((read_u32(memory, entry), read_u32(memory, entry + 4L).to_int()))
  }
  pairs
}
