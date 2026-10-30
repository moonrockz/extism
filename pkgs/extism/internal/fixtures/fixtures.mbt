///|
fn hex(text : String) -> Bytes {
  let digit = (c : Char) => {
    let code = c.to_int()
    if code <= '9'.to_int() {
      code - '0'.to_int()
    } else {
      code - 'a'.to_int() + 10
    }
  }
  let digits = text.iter().collect()
  Bytes::makei(digits.length() / 2, i => {
    (digit(digits[2 * i]) * 16 + digit(digits[2 * i + 1])).to_byte()
  })
}

///|
/// ```wat
/// (module (func (export "add") (param i64 i64) (result i64) local.get 0 local.get 1 i64.add))
/// ```
pub fn add() -> Bytes {
  hex(
    "0061736d0100000001070160027e7e017e030201000707010361646400000a09010700200020017c0b",
  )
}

///|
/// ```wat
/// (module (memory 16) (func (export "f")))
/// ```
pub fn big() -> Bytes {
  hex(
    "0061736d01000000010401600000030201000503010010070501016600000a040102000b",
  )
}

///|
/// ```wat
/// (module (memory i64 1 2 shared) (func (export "v") v128.const i32x4 0 0 0 0 drop))
/// ```
pub fn features() -> Bytes {
  hex(
    "0061736d0100000001040160000003020100050401070102070501017600000a17011500fd0c000000000000000000000000000000001a0b",
  )
}

///|
/// ```wat
/// (module (memory (export "memory") 1)
///   (func (export "grow") (param i32) (result i32) local.get 0 memory.grow)
///   (func (export "size") (result i32) memory.size)
///   (func (export "grow_then_trap") (param i32) local.get 0 memory.grow i32.const -1 i32.eq if unreachable end))
/// ```
pub fn grow() -> Bytes {
  hex(
    "0061736d01000000010e0360017f017f6000017f60017f000304030001020503010001072904066d656d6f727902000467726f7700000473697a6500010e67726f775f7468656e5f7472617000020a1b030600200040000b04003f000b0d0020004000417f460440000b0b",
  )
}

///|
/// ```wat
/// (module (import "env" "add" (func $add (param i64 i64) (result i64))) (func (export "call_add") (param i64 i64) (result i64) local.get 0 local.get 1 call $add))
/// ```
pub fn host() -> Bytes {
  hex(
    "0061736d0100000001070160027e7e017e020b0103656e7603616464000003020100070c010863616c6c5f61646400010a0a0108002000200110000b000d046e616d650106010003616464",
  )
}

///|
/// ```wat
/// (module (import "extism:host/env" "alloc" (func $alloc (param i64) (result i64))) (memory (export "memory") 1) (func (export "run") (param i64) (result i64) local.get 0 call $alloc))
/// ```
pub fn link() -> Bytes {
  hex(
    "0061736d0100000001060160017e017e0219010f65787469736d3a686f73742f656e7605616c6c6f630000030201000503010001071002066d656d6f727902000372756e00010a08010600200010000b000f046e616d650108010005616c6c6f63",
  )
}

///|
/// ```wat
/// (module (func (export "v") v128.const i32x4 0 0 0 0 drop))
/// ```
pub fn simd() -> Bytes {
  hex(
    "0061736d0100000001040160000003020100070501017600000a17011500fd0c000000000000000000000000000000001a0b",
  )
}

///|
/// ```wat
/// (module (memory 1)
///   (func (export "boom") unreachable)
///   (func (export "spin") (loop br 0))
///   (func (export "divide") (param i32) (result i32) i32.const 1 local.get 0 i32.div_s)
///   (func (export "load") (param i32) (result i32) local.get 0 i32.load))
/// ```
pub fn traps() -> Bytes {
  hex(
    "0061736d0100000001090260000060017f017f030504000001010503010001071f0404626f6f6d0000047370696e0001066469766964650002046c6f616400030a1d040300000b070003400c000b0b0700410120006d0b070020002802000b",
  )
}
