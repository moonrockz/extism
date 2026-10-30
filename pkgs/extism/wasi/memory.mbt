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
/// The most iovecs that one call takes.
pub let max_iovecs : Int = 1024

///|
/// Whether `length` bytes at `offset` are inside the memory.
fn[M : GuestMemory] inside(memory : M, offset : Int64, length : Int64) -> Bool {
  offset >= 0L && length >= 0L && offset + length <= memory.size()
}

///|
/// The `(buffer, length)` pairs of an iovec array of at most `max_iovecs` entries, each of them inside
/// the memory. Gives `None` for too many iovecs. A pair outside the memory raises `OutOfBounds`, before
/// any byte of a buffer is read.
fn[M : GuestMemory] iovecs(
  memory : M,
  at : Int64,
  count : Int64,
) -> Array[(Int64, Int64)]? raise GuestMemoryError {
  guard count <= max_iovecs.to_int64() else { return None }
  let entries = memory.read(at, (8L * count).to_int())
  let word = (i : Int) => {
    entries[i].to_int64() |
    (entries[i + 1].to_int64() << 8) |
    (entries[i + 2].to_int64() << 16) |
    (entries[i + 3].to_int64() << 24)
  }
  let pairs = Array::makei(count.to_int(), i => (word(8 * i), word(8 * i + 4)))
  for pair in pairs {
    guard inside(memory, pair.0, pair.1) else {
      raise OutOfBounds(pair.0, pair.1.to_int())
    }
  }
  Some(pairs)
}
