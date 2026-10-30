///|
/// The export that the js rewrite adds: a mutable `i32` global that is 1 after a refused
/// `memory.grow`.
pub let grow_flag_export : String = "__moonrockz_extism_grow_refused"

///|
fn write_unsigned(out : @buffer.Buffer, value : Int64) -> Unit {
  let mut rest = value
  while true {
    let byte = (rest & 0x7fL).to_int()
    rest = (rest.reinterpret_as_uint64() >> 7).reinterpret_as_int64()
    if rest == 0L {
      out.write_byte(byte.to_byte())
      break
    }
    out.write_byte((byte | 0x80).to_byte())
  }
}

///|
fn write_vec_header(out : @buffer.Buffer, count : Int32) -> Unit {
  write_unsigned(out, count.to_int64())
}

///|
fn write_section(out : @buffer.Buffer, id : Int32, payload : Bytes) -> Unit {
  out.write_byte(id.to_byte())
  write_unsigned(out, payload.length().to_int64())
  out.write_bytes(payload)
}

///|
/// The position of a section id in the order that a module must follow.
fn section_rank(id : Int32) -> Int32 {
  match id {
    1 => 1
    2 => 2
    3 => 3
    4 => 4
    5 => 5
    13 => 6
    6 => 7
    7 => 8
    8 => 9
    9 => 10
    12 => 11
    10 => 12
    11 => 13
    _ => 0
  }
}

///|
/// A section payload that appends `extra` entries to a vector section, or makes the section.
fn append_entries(
  module_ : Module,
  id : Int32,
  extra : Array[Bytes],
) -> Bytes raise DecodeError {
  let out = @buffer.Buffer()
  match module_.sections.iter().find_first(s => s.id == id) {
    Some(section) => {
      let reader = Reader::new(module_.bytes, section.start, section.end)
      let count = reader.count()
      write_vec_header(out, count + extra.length())
      out.write_bytes(module_.bytes[reader.at:section.end].to_owned())
    }
    None => write_vec_header(out, extra.length())
  }
  for entry in extra {
    out.write_bytes(entry)
  }
  out.to_bytes()
}

///|
fn encoded(write : (@buffer.Buffer) -> Unit) -> Bytes {
  let out = @buffer.Buffer()
  write(out)
  out.to_bytes()
}

///|
/// The module for the js engine, with the maximum of its memory at most `ceiling` pages and each
/// `memory.grow` of memory 0 sent through an appended function that sets the exported global
/// `grow_flag_export` when the grow is refused. Appended types, functions and globals take the next
/// free indices, so no other index changes.
pub fn Module::for_js(
  self : Module,
  ceiling : Int32,
) -> Bytes raise DecodeError {
  let scan = self.scan()
  let grows = scan.grows
  let type_index = self.types.length()
  let function_index = self.imported_function_count() + self.functions.length()
  let global_index = self.imported_global_count() + self.global_count
  let replaced : Map[Int32, Bytes] = Map([])
  // The memory section with the ceiling as its maximum.
  if self.sections.iter().find_first(s => s.id == 5) is Some(section) {
    let out = @buffer.Buffer()
    let reader = Reader::new(self.bytes, section.start, section.end)
    let count = reader.count()
    write_vec_header(out, count)
    for index in 0..<count {
      let limits = reader.limits([])
      let max = match limits.max {
        Some(max) if index > 0 || max <= ceiling.to_int64() => max
        _ => ceiling.to_int64()
      }
      let flags = (if limits.shared { 0x02 } else { 0 }) |
        (if limits.is64 { 0x04 } else { 0 }) |
        0x01
      out.write_byte(flags.to_byte())
      write_unsigned(out, limits.min)
      write_unsigned(out, max)
    }
    replaced[5] = out.to_bytes()
  }
  if !grows.is_empty() {
    replaced[1] = append_entries(self, 1, [b"\x60\x01\x7f\x01\x7f"])
    replaced[3] = append_entries(self, 3, [
      encoded(out => write_unsigned(out, type_index.to_int64())),
    ])
    replaced[6] = append_entries(self, 6, [b"\x7f\x01\x41\x00\x0b"])
    replaced[7] = append_entries(self, 7, [
      encoded(out => {
        let name = @utf8.encode(grow_flag_export)
        write_unsigned(out, name.length().to_int64())
        out.write_bytes(name)
        out.write_byte(b'\x03')
        write_unsigned(out, global_index.to_int64())
      }),
    ])
    // The code section: each `memory.grow 0` becomes a call of the appended function.
    let hook = encoded(out => {
      // One local i32 for the result of the grow.
      out.write_bytes(b"\x01\x01\x7f")
      out.write_bytes(
        b"\x20\x00\x40\x00\x22\x01\x41\x7f\x46\x04\x40\x41\x01\x24",
      )
      write_unsigned(out, global_index.to_int64())
      out.write_bytes(b"\x0b\x20\x01\x0b")
    })
    let call = encoded(out => {
      out.write_byte(b'\x10')
      write_unsigned(out, function_index.to_int64())
    })
    let code = @buffer.Buffer()
    write_vec_header(code, self.bodies.length() + 1)
    let mut next = 0
    for body in self.bodies {
      let out = @buffer.Buffer()
      let mut copied = body.start
      while next < grows.length() && grows[next] < body.end {
        out.write_bytes(self.bytes[copied:grows[next]].to_owned())
        out.write_bytes(call)
        // `memory.grow 0` is the opcode and one byte for the memory index.
        copied = grows[next] + 2
        next += 1
      }
      out.write_bytes(self.bytes[copied:body.end].to_owned())
      let bytes = out.to_bytes()
      write_unsigned(code, bytes.length().to_int64())
      code.write_bytes(bytes)
    }
    write_unsigned(code, hook.length().to_int64())
    code.write_bytes(hook)
    replaced[10] = code.to_bytes()
  }
  // Write the sections in order, with the new ones at their place.
  let out = @buffer.Buffer()
  out.write_bytes(self.bytes[0:8].to_owned())
  let written : Map[Int32, Bool] = Map([])
  let emit_missing_before = (rank : Int32) => {
    let ids = replaced.keys().collect()
    ids.sort_by_key(id => section_rank(id))
    for id in ids {
      if section_rank(id) < rank && !written.contains(id) {
        written[id] = true
        write_section(out, id, replaced[id])
      }
    }
  }
  for section in self.sections {
    let rank = section_rank(section.id)
    if rank > 0 {
      emit_missing_before(rank)
    }
    if replaced.get(section.id) is Some(payload) && section_rank(section.id) > 0 {
      written[section.id] = true
      write_section(out, section.id, payload)
    } else {
      write_section(
        out,
        section.id,
        self.bytes[section.start:section.end].to_owned(),
      )
    }
  }
  emit_missing_before(100)
  out.to_bytes()
}
