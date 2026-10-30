///|
/// What a pass over instructions found.
priv struct Scan {
  features : Array[Feature]
  /// The offset of each `memory.grow 0` instruction.
  grows : Array[Int32]
  mut globals : Bool
}

///|
fn Scan::new() -> Scan {
  { features: [], grows: [], globals: false, }
}

///|
fn Reader::block_type(self : Reader, scan : Scan) -> Unit raise DecodeError {
  let code = self.bytes[self.at].to_int()
  if code == 0x40 ||
    (code >= 0x7b && code <= 0x7f) ||
    code == 0x70 ||
    code == 0x6f {
    if code == 0x7b {
      add_feature(scan.features, Simd)
    }
    self.at += 1
  } else if code == 0x64 || code == 0x63 {
    add_feature(scan.features, Gc)
    self.at += 1
    self.skip_signed()
  } else {
    // A type index, as a signed 33-bit number.
    self.skip_signed()
  }
}

///|
fn Reader::memarg(self : Reader) -> Unit raise DecodeError {
  let align = self.u32()
  if (align & 0x40) != 0 {
    // The memory index of the multi-memory proposal.
    self.u32() |> ignore
  }
  self.unsigned(bits=64) |> ignore
}

///|
/// Reads the immediates of the instruction `opcode`, which the reader has read. Gives false when the
/// instruction needs a feature whose encoding the reader does not follow; the feature is then in
/// `scan.features` and the rest of the body cannot be read.
fn Reader::instruction(
  self : Reader,
  opcode : Int32,
  scan : Scan,
) -> Bool raise DecodeError {
  match opcode {
    0x00 | 0x01 | 0x05 | 0x0b | 0x0f | 0x1a | 0x1b => ()
    0x02 | 0x03 | 0x04 => self.block_type(scan)
    0x06 | 0x07 | 0x08 | 0x09 | 0x0a | 0x18 | 0x19 | 0x1f => {
      add_feature(scan.features, ExceptionHandling)
      return false
    }
    0x0c | 0x0d => self.u32() |> ignore
    0x0e => {
      for _ in 0..<self.u32() {
        self.u32() |> ignore
      }
      self.u32() |> ignore
    }
    0x10 => self.u32() |> ignore
    0x11 => {
      self.u32() |> ignore
      self.u32() |> ignore
    }
    0x12 | 0x13 => {
      add_feature(scan.features, TailCall)
      return false
    }
    0x14 | 0x15 | 0xd3 | 0xd4 | 0xd5 | 0xd6 => {
      add_feature(scan.features, Gc)
      return false
    }
    0x1c =>
      for _ in 0..<self.u32() {
        let code = self.byte()
        if code == 0x7b {
          add_feature(scan.features, Simd)
        }
      }
    0x20 | 0x21 | 0x22 => self.u32() |> ignore
    0x23 | 0x24 => {
      scan.globals = true
      self.u32() |> ignore
    }
    0x25 | 0x26 => self.u32() |> ignore
    _ if opcode >= 0x28 && opcode <= 0x3e => self.memarg()
    0x3f => self.u32() |> ignore
    0x40 => {
      let at = self.at - 1
      if self.u32() == 0 {
        scan.grows.push(at)
      }
    }
    0x41 | 0x42 => self.skip_signed()
    0x43 => self.skip(4)
    0x44 => self.skip(8)
    _ if opcode >= 0x45 && opcode <= 0xc4 => ()
    0xd0 => {
      let code = self.bytes[self.at].to_int()
      if code == 0x70 || code == 0x6f {
        self.at += 1
      } else {
        add_feature(scan.features, Gc)
        self.skip_signed()
      }
    }
    0xd1 => ()
    0xd2 => self.u32() |> ignore
    0xfc => {
      let sub = self.u32()
      match sub {
        _ if sub <= 7 => ()
        8 => {
          self.u32() |> ignore
          self.u32() |> ignore
        }
        9 => self.u32() |> ignore
        10 => {
          self.u32() |> ignore
          self.u32() |> ignore
        }
        11 => self.u32() |> ignore
        12 | 14 => {
          self.u32() |> ignore
          self.u32() |> ignore
        }
        13 | 15 | 16 | 17 => self.u32() |> ignore
        _ => {
          add_feature(scan.features, Unknown("instruction 0xfc \{sub}"))
          return false
        }
      }
    }
    0xfd => {
      add_feature(scan.features, Simd)
      return false
    }
    0xfe => {
      add_feature(scan.features, Threads)
      return false
    }
    0xfb => {
      add_feature(scan.features, Gc)
      return false
    }
    _ => {
      add_feature(scan.features, Unknown("instruction \{opcode}"))
      return false
    }
  }
  true
}

///|
/// Reads the locals and instructions of one function body.
fn Reader::body(self : Reader, scan : Scan) -> Unit raise DecodeError {
  for _ in 0..<self.u32() {
    self.u32() |> ignore
    self.val_type(scan.features) |> ignore
  }
  while !self.done() {
    let opcode = self.byte()
    if !self.instruction(opcode, scan) {
      // The rest of this body uses an encoding that the reader does not follow.
      self.at = self.end
    }
  }
}

///|
fn Module::scan(self : Module) -> Scan raise DecodeError {
  let scan = Scan::new()
  for body in self.bodies {
    Reader::new(self.bytes, body.start, body.end).body(scan)
  }
  scan
}

///|
fn Module::scan_code(self : Module) -> Unit raise DecodeError {
  for feature in self.scan().features {
    add_feature(self.features, feature)
  }
}

///|
/// Whether a function body reads or writes a global.
pub fn Module::uses_globals(self : Module) -> Bool raise DecodeError {
  self.scan().globals
}
