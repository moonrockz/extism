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
fn Reader::u32(self : Reader) -> Int32 raise DecodeError {
  let value = self.unsigned()
  guard value >= 0L && value <= 0xffffffffL else {
    raise self.fail("number is larger than 32 bits")
  }
  value.to_int()
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
  guard count >= 0 && self.at + count <= self.end else {
    raise self.fail("unexpected end of the bytes")
  }
  self.at += count
}

///|
fn Reader::name(self : Reader) -> String raise DecodeError {
  let length = self.u32()
  let start = self.at
  self.skip(length)
  @utf8.decode(self.bytes[start:start + length]) catch {
    _ => raise DecodeError(start, "name is not UTF-8")
  }
}
