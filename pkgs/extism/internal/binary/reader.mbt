///|
/// A WASM binary that cannot be read: the byte offset and the rule that the bytes break.
pub suberror DecodeError {
  DecodeError(Int32, String)
}

///|
/// A cursor over the bytes of a module.
priv struct Reader {
  bytes : Bytes
  mut at : Int32
  end : Int32
}

///|
fn Reader::new(bytes : Bytes, start : Int32, end : Int32) -> Reader {
  { bytes, at: start, end, }
}

///|
fn Reader::fail(self : Reader, rule : String) -> DecodeError {
  DecodeError(self.at, rule)
}

///|
fn Reader::done(self : Reader) -> Bool {
  self.at >= self.end
}

///|
fn Reader::byte(self : Reader) -> Int32 raise DecodeError {
  guard self.at < self.end else {
    raise self.fail("unexpected end of the bytes")
  }
  let value = self.bytes[self.at].to_int()
  self.at += 1
  value
}

///|
/// The next byte, which the reader does not pass.
fn Reader::peek(self : Reader) -> Int32 raise DecodeError {
  guard self.at < self.end else {
    raise self.fail("unexpected end of the bytes")
  }
  self.bytes[self.at].to_int()
}

///|
/// The element count of a vector. Each element takes at least one byte, so a count larger than the
/// bytes left is refused before anything is allocated for it.
fn Reader::count(self : Reader) -> Int32 raise DecodeError {
  let count = self.u32()
  guard count >= 0 && count <= self.end - self.at else {
    raise self.fail("vector count \{count} is larger than the bytes left")
  }
  count
}

///|
/// An unsigned LEB128 number of at most `bits` bits.
fn Reader::unsigned(
  self : Reader,
  bits~ : Int32 = 32,
) -> Int64 raise DecodeError {
  let mut result = 0L
  let mut shift = 0
  while true {
    let byte = self.byte()
    guard shift < bits + 7 else { raise self.fail("LEB128 number is too long") }
    result = result | ((byte & 0x7f).to_int64() << shift)
    shift += 7
    if (byte & 0x80) == 0 {
      break
    }
  }
  result
}

///|
/// A u32 number: an index, a count, a size or an immediate. In a module that the engines take, each
/// such number is bounded by the bytes or by a vector count, so a number above the `Int32` maximum is
/// refused. The result is never negative, and an index check needs only its upper bound.
fn Reader::u32(self : Reader) -> Int32 raise DecodeError {
  let value = self.unsigned()
  guard value >= 0L && value <= 0x7fffffffL else {
    raise self.fail("number \{value} is larger than 2^31 - 1")
  }
  value.to_int()
}

///|
/// An index into a vector of `bound` elements. `what` names the index in the error.
fn Reader::index(
  self : Reader,
  bound : Int32,
  what : String,
) -> Int32 raise DecodeError {
  let at = self.at
  let index = self.u32()
  guard index < bound else {
    raise DecodeError(at, "\{what}: index \{index} is not below \{bound}")
  }
  index
}

///|
/// A byte length, which cannot pass the end of the bytes.
fn Reader::length(self : Reader) -> Int32 raise DecodeError {
  let length = self.u32()
  guard length <= self.end - self.at else {
    raise self.fail("length \{length} is larger than the bytes left")
  }
  length
}

///|
/// A signed LEB128 number; its value is not needed, only its length.
fn Reader::skip_signed(self : Reader) -> Unit raise DecodeError {
  let mut count = 0
  while (self.byte() & 0x80) != 0 {
    count += 1
    guard count < 10 else { raise self.fail("LEB128 number is too long") }
  }
}

///|
fn Reader::skip(self : Reader, count : Int32) -> Unit raise DecodeError {
  // `self.end - self.at` cannot overflow; `self.at + count` can.
  guard count >= 0 && count <= self.end - self.at else {
    raise self.fail("unexpected end of the bytes")
  }
  self.at += count
}

///|
fn Reader::name(self : Reader) -> String raise DecodeError {
  let length = self.length()
  let start = self.at
  self.skip(length)
  @utf8.decode(self.bytes[start:start + length]) catch {
    _ => raise DecodeError(start, "name is not UTF-8")
  }
}
