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
/// (module (import "wasi_snapshot_preview1" "fd_write" (func (param i32 i32 i32 i32) (result i32))) (func (export "handle") (result i32) (i32.const 0)))
/// ```
pub fn fd_write_import() -> Bytes {
  hex(
    "0061736d01000000010d0260047f7f7f7f017f6000017f02230116776173695f736e617073686f745f70726576696577310866645f7772697465000003020101070a010668616e646c6500010a0601040041000b",
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
/// (module (func (export "_initialize") unreachable) (func (export "handle") (result i32) (i32.const 0)))
/// ```
pub fn init_trap() -> Bytes {
  hex(
    "0061736d010000000108026000006000017f03030200010718020b5f696e697469616c697a6500000668616e646c6500010a0a020300000b040041000b",
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
/// (module
///   (import "extism:host/env" "alloc" (func $alloc (param i64) (result i64)))
///   (import "extism:host/env" "free" (func $free (param i64)))
///   (import "extism:host/env" "length" (func $length (param i64) (result i64)))
///   (import "extism:host/env" "load_u8" (func $load_u8 (param i64) (result i32)))
///   (import "extism:host/env" "store_u8" (func $store_u8 (param i64 i32)))
///   (import "extism:host/env" "store_u64" (func $store_u64 (param i64 i64)))
///   (import "extism:host/env" "input_length" (func $input_length (result i64)))
///   (import "extism:host/env" "input_load_u8" (func $input_load_u8 (param i64) (result i32)))
///   (import "extism:host/env" "output_set" (func $output_set (param i64 i64)))
///   (import "extism:host/env" "error_set" (func $error_set (param i64)))
///   (import "extism:host/env" "config_get" (func $config_get (param i64) (result i64)))
///   (import "extism:host/env" "var_get" (func $var_get (param i64) (result i64)))
///   (import "extism:host/env" "var_set" (func $var_set (param i64 i64)))
///   (import "extism:host/env" "http_request" (func $http_request (param i64 i64) (result i64)))
///   (import "extism:host/env" "http_status_code" (func $http_status_code (result i32)))
///   (import "extism:host/env" "log_info" (func $log_info (param i64)))
///   (import "extism:host/env" "get_log_level" (func $get_log_level (result i32)))
///   (import "extism:host/user" "lookup" (func $lookup (param i64) (result i64)))
///   (memory (export "memory") 1)
///   (data (i32.const 0) "bad input")
///   (data (i32.const 16) "mode")
///   (data (i32.const 32) "{\"method\":\"POST\",\"url\":\"https://example.com/api\"}")
///   (data (i32.const 96) "big")
///   (data (i32.const 112) "hello")
///   ;; A new block with the plugin memory bytes [ptr, ptr + len).
///   (func $put (param $ptr i32) (param $len i32) (result i64)
///     (local $h i64) (local $i i32)
///     (local.set $h (call $alloc (i64.extend_i32_u (local.get $len))))
///     (block $done (loop $copy
///       (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
///       (call $store_u8 (i64.add (local.get $h) (i64.extend_i32_u (local.get $i)))
///         (i32.load8_u (i32.add (local.get $ptr) (local.get $i))))
///       (local.set $i (i32.add (local.get $i) (i32.const 1)))
///       (br $copy)))
///     (local.get $h))
///   ;; A new block with a copy of the input.
///   (func $input (result i64)
///     (local $h i64) (local $i i64) (local $n i64)
///     (local.set $n (call $input_length))
///     (local.set $h (call $alloc (local.get $n)))
///     (block $done (loop $copy
///       (br_if $done (i64.ge_u (local.get $i) (local.get $n)))
///       (call $store_u8 (i64.add (local.get $h) (local.get $i)) (call $input_load_u8 (local.get $i)))
///       (local.set $i (i64.add (local.get $i) (i64.const 1)))
///       (br $copy)))
///     (local.get $h))
///   (func $out (param $h i64) (call $output_set (local.get $h) (call $length (local.get $h))))
///   (func (export "echo") (result i32) (call $out (call $input)) (i32.const 0))
///   (func (export "fail") (result i32) (call $error_set (call $put (i32.const 0) (i32.const 9))) (i32.const 1))
///   (func (export "code") (result i32) (i32.const 7))
///   (func (export "empty_error") (result i32)
///     (local $h i64)
///     (local.set $h (call $put (i32.const 0) (i32.const 9)))
///     (call $error_set (local.get $h))
///     (call $free (local.get $h))
///     (i32.const 0))
///   (func (export "config") (result i32) (call $out (call $config_get (call $put (i32.const 16) (i32.const 4)))) (i32.const 0))
///   (func (export "var_roundtrip") (result i32)
///     (call $var_set (call $put (i32.const 96) (i32.const 3)) (call $input))
///     (call $out (call $var_get (call $put (i32.const 96) (i32.const 3))))
///     (i32.const 0))
///   (func (export "var_big") (result i32)
///     (call $var_set (call $put (i32.const 96) (i32.const 3)) (call $alloc (i64.const 2048)))
///     (i32.const 0))
///   (func (export "http") (result i32)
///     (local $body i64) (local $h i64)
///     (local.set $body (call $http_request (call $put (i32.const 32) (i32.const 49)) (i64.const 0)))
///     (local.set $h (call $alloc (i64.const 16)))
///     (call $store_u64 (local.get $h) (i64.extend_i32_u (call $http_status_code)))
///     (call $store_u64 (i64.add (local.get $h) (i64.const 8)) (call $length (local.get $body)))
///     (call $out (local.get $h))
///     (i32.const 0))
///   (func (export "log") (result i32) (call $log_info (call $put (i32.const 112) (i32.const 5))) (i32.const 0))
///   (func (export "log_level") (result i32)
///     (local $h i64)
///     (local.set $h (call $alloc (i64.const 8)))
///     (call $store_u64 (local.get $h) (i64.extend_i32_u (call $get_log_level)))
///     (call $out (local.get $h))
///     (i32.const 0))
///   (func (export "lookup") (result i32) (call $out (call $lookup (call $input))) (i32.const 0))
///   (func (export "kernel_full") (result i32)
///     (if (i64.eqz (call $alloc (i64.const 2097152))) (then unreachable))
///     (i32.const 0))
///   (func (export "boom") (result i32) unreachable))
/// ```
pub fn plugin() -> Bytes {
  hex(
    "0061736d01000000012d0960017e017e60017e0060017e017f60027e7f0060027e7e006000017e60027e7e017e6000017f60027f7f017e02fa03120f65787469736d3a686f73742f656e7605616c6c6f6300000f65787469736d3a686f73742f656e76046672656500010f65787469736d3a686f73742f656e76066c656e67746800000f65787469736d3a686f73742f656e76076c6f61645f753800020f65787469736d3a686f73742f656e760873746f72655f753800030f65787469736d3a686f73742f656e760973746f72655f75363400040f65787469736d3a686f73742f656e760c696e7075745f6c656e67746800050f65787469736d3a686f73742f656e760d696e7075745f6c6f61645f753800020f65787469736d3a686f73742f656e760a6f75747075745f73657400040f65787469736d3a686f73742f656e76096572726f725f73657400010f65787469736d3a686f73742f656e760a636f6e6669675f67657400000f65787469736d3a686f73742f656e76077661725f67657400000f65787469736d3a686f73742f656e76077661725f73657400040f65787469736d3a686f73742f656e760c687474705f7265717565737400060f65787469736d3a686f73742f656e7610687474705f7374617475735f636f646500070f65787469736d3a686f73742f656e76086c6f675f696e666f00010f65787469736d3a686f73742f656e760d6765745f6c6f675f6c6576656c00071065787469736d3a686f73742f75736572066c6f6f6b757000000311100805010707070707070707070707070705030100010787010e066d656d6f72790200046563686f0015046661696c001604636f646500170b656d7074795f6572726f72001806636f6e66696700190d7661725f726f756e6474726970001a077661725f626967001b0468747470001c036c6f67001d096c6f675f6c6576656c001e066c6f6f6b7570001f0b6b65726e656c5f66756c6c002004626f6f6d00210ad802103502017e017f2001ad1000210202400340200320014f0d0120022003ad7c200020036a2d00001004200341016a21030c000b0b20020b3101037e1006210220021000210002400340200120025a0d01200020017c200110071004200142017c21010c000b0b20000b0a0020002000100210080b08001013101441000b0c00410041091012100941010b040041070b1601017e4100410910122100200010092000100141000b0e00411041041012100a101441000b1a0041e000410310121013100c41e00041031012100b101441000b120041e000410310124280101000100c41000b2e01027e4120413110124200100d21004210100021012001100ead1005200142087c2000100210052001101441000b0d0041f00041051012100f41000b1701017e42081000210020001010ad10052000101441000b0a0010131011101441000b100042808080011000500440000b41000b0300000b0b62050041000b0962616420696e7075740041100b046d6f64650041200b317b226d6574686f64223a22504f5354222c2275726c223a2268747470733a2f2f6578616d706c652e636f6d2f617069227d0041e0000b036269670041f0000b0568656c6c6f00b902046e616d6501d801150005616c6c6f6301046672656502066c656e67746803076c6f61645f7538040873746f72655f7538050973746f72655f753634060c696e7075745f6c656e677468070d696e7075745f6c6f61645f7538080a6f75747075745f73657409096572726f725f7365740a0a636f6e6669675f6765740b077661725f6765740c077661725f7365740d0c687474705f726571756573740e10687474705f7374617475735f636f64650f086c6f675f696e666f100d6765745f6c6f675f6c6576656c11066c6f6f6b757012037075741305696e70757414036f75740238061204000370747201036c656e020168030169130300016801016902016e140100016818010001681c020004626f64790101681e01000168031d0212020004646f6e650104636f707913020004646f6e650104636f7079",
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

///|
/// ```wat
/// (module (import "env" "secret_syscall" (func (param i32) (result i32))) (func (export "handle") (result i32) (i32.const 0)))
/// ```
pub fn unknown_import() -> Bytes {
  hex(
    "0061736d01000000010a0260017f017f6000017f02160103656e760e7365637265745f73797363616c6c000003020101070a010668616e646c6500010a0601040041000b",
  )
}

///|
/// ```wat
/// (module
///   (import "wasi_snapshot_preview1" "fd_write" (func $fd_write (param i32 i32 i32 i32) (result i32)))
///   (import "wasi_snapshot_preview1" "proc_exit" (func $proc_exit (param i32)))
///   (import "wasi_snapshot_preview1" "path_symlink" (func $path_symlink (param i32 i32 i32 i32 i32) (result i32)))
///   (import "extism:host/env" "alloc" (func $alloc (param i64) (result i64)))
///   (import "extism:host/env" "store_u8" (func $store_u8 (param i64 i32)))
///   (import "extism:host/env" "output_set" (func $output_set (param i64 i64)))
///   (memory (export "memory") 1)
///   (global $starts (mut i32) (i32.const 0))
///   (data (i32.const 0) "\10\00\00\00\05\00\00\00")
///   (data (i32.const 16) "hello")
///   (func (export "_initialize") (global.set $starts (i32.add (global.get $starts) (i32.const 1))))
///   (func $byte_out (param $v i32)
///     (local $h i64)
///     (local.set $h (call $alloc (i64.const 1)))
///     (call $store_u8 (local.get $h) (local.get $v))
///     (call $output_set (local.get $h) (i64.const 1)))
///   (func (export "starts") (result i32) (call $byte_out (global.get $starts)) (i32.const 0))
///   (func (export "print") (result i32) (drop (call $fd_write (i32.const 1) (i32.const 0) (i32.const 1) (i32.const 8))) (i32.const 0))
///   (func (export "symlink") (result i32) (call $byte_out (call $path_symlink (i32.const 0) (i32.const 0) (i32.const 3) (i32.const 0) (i32.const 0))) (i32.const 0))
///   (func (export "done") (result i32) (call $byte_out (i32.const 100)) (call $proc_exit (i32.const 0)) (i32.const 0))
///   (func (export "exit3") (result i32) (call $proc_exit (i32.const 3)) (i32.const 0)))
/// ```
pub fn wasi_plugin() -> Bytes {
  hex(
    "0061736d01000000012c0860047f7f7f7f017f60017f0060057f7f7f7f7f017f60017e017e60027e7f0060027e7e006000006000017f02bc010616776173695f736e617073686f745f70726576696577310866645f7772697465000016776173695f736e617073686f745f70726576696577310970726f635f65786974000116776173695f736e617073686f745f70726576696577310c706174685f73796d6c696e6b00020f65787469736d3a686f73742f656e7605616c6c6f6300030f65787469736d3a686f73742f656e760873746f72655f753800040f65787469736d3a686f73742f656e760a6f75747075745f73657400050308070601070707070705030100010606017f0141000b074207066d656d6f727902000b5f696e697469616c697a650006067374617274730008057072696e7400090773796d6c696e6b000a04646f6e65000b056578697433000c0a65070900230041016a24000b1601017e4201100321012001200010042001420110050b08002300100741000b0f00410141004101410810001a41000b1200410041004103410041001002100741000b0d0041e40010074100100141000b08004103100141000b0b18020041000b0810000000050000000041100b0568656c6c6f0068046e616d65014b07000866645f7772697465010970726f635f65786974020c706174685f73796d6c696e6b0305616c6c6f63040873746f72655f7538050a6f75747075745f7365740708627974655f6f757402090107020001760101680709010006737461727473",
  )
}

///|
/// ```wat
/// (module
///   (memory (export "memory") 1)
///   (func (export "lanes") (param i32) (result i32)
///     (i32x4.extract_lane 2
///       (i32x4.mul (i32x4.splat (local.get 0)) (v128.const i32x4 1 2 3 4))))
///   (func (export "shuffle_sum") (result i32)
///     (v128.store (i32.const 16) (v128.const i8x16 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15))
///     (i32x4.extract_lane 0
///       (i8x16.shuffle 15 14 13 12 3 2 1 0 0 0 0 0 0 0 0 0
///         (v128.load (i32.const 16)) (v128.load (i32.const 16)))))
///   (func (export "float") (result f64)
///     (f64x2.extract_lane 1
///       (f64x2.add (f64x2.splat (f64.const 1.5)) (v128.const f64x2 0.25 2.25)))))
/// ```
pub fn simd_probe() -> Bytes {
  hex(
    "0061736d01000000010e0360017f017f6000017f6000017c0304030001020503010001072804066d656d6f72790200056c616e657300000b73687566666c655f73756d000105666c6f617400020a8201031e002000fd11fd0c01000000020000000300000004000000fdb501fd1b020b3b004110fd0c000102030405060708090a0b0c0d0e0ffd0b04004110fd0004004110fd000400fd0d0f0e0d0c030201000000000000000000fd1b000b250044000000000000f83ffd14fd0c000000000000d03f0000000000000240fdf001fd21010b",
  )
}

///|
/// ```wat
/// (module
///   (import "env" "seen" (func $seen))
///   (memory 1)
///   (global $count (mut i32) (i32.const 0))
///   (func $start (call $seen) (global.set $count (i32.add (global.get $count) (i32.const 1))))
///   (start $start)
///   (func (export "count") (result i32) (global.get $count)))
/// ```
pub fn start_host() -> Bytes {
  hex(
    "0061736d010000000108026000006000017f020c0103656e76047365656e0000030302000105030100010606017f0141000b07090105636f756e7400020801010a12020b001000230041016a24000b040023000b001f046e616d65010e0200047365656e010573746172740708010005636f756e74",
  )
}

///|
/// ```wat
/// (module (func $start unreachable) (start $start) (func (export "f")))
/// ```
pub fn start_trap() -> Bytes {
  hex(
    "0061736d010000000104016000000303020000070501016600010801000a08020300000b02000b000f046e616d6501080100057374617274",
  )
}

///|
/// ```wat
/// (module
///   (func $spin (loop $l (br $l)))
///   (start $spin)
///   (func (export "run") (result i32) (i32.const 0)))
/// ```
pub fn start_loop() -> Bytes {
  hex(
    "0061736d010000000108026000006000017f03030200010707010372756e00010801000a0e02070003400c000b0b040041000b0016046e616d6501070100047370696e030601000100016c",
  )
}

///|
/// ```wat
/// (module
///   (func (export "_initialize") (loop $l (br $l)))
///   (func (export "run") (result i32) (i32.const 0)))
/// ```
pub fn init_loop() -> Bytes {
  hex(
    "0061736d010000000108026000006000017f03030200010715020b5f696e697469616c697a6500000372756e00010a0e02070003400c000b0b040041000b000d046e616d65030601000100016c",
  )
}

///|
/// A plugin whose `count` gives two digits: how often `__wasm_call_ctors` and `__post_instantiate`
/// ran, then how often `_initialize` ran.
/// ```wat
/// (module
///   (import "extism:host/env" "alloc" (func $alloc (param i64) (result i64)))
///   (import "extism:host/env" "store_u8" (func $store_u8 (param i64 i32)))
///   (import "extism:host/env" "output_set" (func $output_set (param i64 i64)))
///   (global $ctors (mut i32) (i32.const 0))
///   (global $inits (mut i32) (i32.const 0))
///   (func (export "__wasm_call_ctors")
///     (global.set $ctors (i32.add (global.get $ctors) (i32.const 1))))
///   (func (export "__post_instantiate")
///     (global.set $ctors (i32.add (global.get $ctors) (i32.const 1))))
///   (func (export "_initialize")
///     (global.set $inits (i32.add (global.get $inits) (i32.const 1))))
///   (func (export "count") (result i32) (local $h i64)
///     (local.set $h (call $alloc (i64.const 2)))
///     (call $store_u8 (local.get $h) (i32.add (i32.const 48) (global.get $ctors)))
///     (call $store_u8 (i64.add (local.get $h) (i64.const 1)) (i32.add (i32.const 48) (global.get $inits)))
///     (call $output_set (local.get $h) (i64.const 2))
///     (i32.const 0)))
/// ```
pub fn ctors() -> Bytes {
  hex(
    "0061736d0100000001170560017e017e60027e7f0060027e7e006000006000017f0251030f65787469736d3a686f73742f656e7605616c6c6f6300000f65787469736d3a686f73742f656e760873746f72655f753800010f65787469736d3a686f73742f656e760a6f75747075745f736574000203050403030304060b027f0141000b7f0141000b074004115f5f7761736d5f63616c6c5f63746f72730003125f5f706f73745f696e7374616e746961746500040b5f696e697469616c697a65000505636f756e7400060a47040900230041016a24000b0900230041016a24000b0900230141016a24010b2701017e4202100021002000413023006a1001200042017c413023016a100120004202100241000b003e046e616d65011e030005616c6c6f63010873746f72655f7538020a6f75747075745f7365740206010601000168070f02000563746f72730105696e697473",
  )
}

///|
/// The `ctors` plugin with a `__wasm_call_ctors` that takes an `i32`, and no `__post_instantiate`.
pub fn ctors_wrong_type() -> Bytes {
  hex(
    "0061736d01000000011b0660017e017e60027e7f0060027e7e0060017f006000006000017f0251030f65787469736d3a686f73742f656e7605616c6c6f6300000f65787469736d3a686f73742f656e760873746f72655f753800010f65787469736d3a686f73742f656e760a6f75747075745f7365740002030403030405060b027f0141000b7f0141000b072b03115f5f7761736d5f63616c6c5f63746f727300030b5f696e697469616c697a65000405636f756e7400050a3d030900230041016a24000b0900230141016a24010b2701017e4202100021002000413023006a1001200042017c413023016a100120004202100241000b003e046e616d65011e030005616c6c6f63010873746f72655f7538020a6f75747075745f7365740206010501000168070f02000563746f72730105696e697473",
  )
}

///|
/// A WASI plugin that does not export its memory.
/// ```wat
/// (module
///   (import "wasi_snapshot_preview1" "fd_write" (func $fd_write (param i32 i32 i32 i32) (result i32)))
///   (memory 1)
///   (data (i32.const 16) "hello")
///   (func (export "print") (result i32)
///     (i32.store (i32.const 0) (i32.const 16))
///     (i32.store (i32.const 4) (i32.const 5))
///     (drop (call $fd_write (i32.const 1) (i32.const 0) (i32.const 1) (i32.const 8)))
///     (i32.const 0)))
/// ```
pub fn wasi_hidden_memory() -> Bytes {
  hex(
    "0061736d01000000010d0260047f7f7f7f017f6000017f02230116776173695f736e617073686f745f70726576696577310866645f77726974650000030201010503010001070901057072696e7400010a1f011d004100411036020041044105360200410141004101410810001a41000b0b0b010041100b0568656c6c6f0012046e616d65010b01000866645f7772697465",
  )
}

///|
/// ```wat
/// (module
///   (func (export "spin_n") (param i32)
///     (loop $l
///       (local.set 0 (i32.sub (local.get 0) (i32.const 1)))
///       (br_if $l (i32.gt_s (local.get 0) (i32.const 0)))))
///   (func (export "one") (result i32) (i32.const 1)))
/// ```
pub fn spin_n() -> Bytes {
  hex(
    "0061736d0100000001090260017f006000017f0303020001071002067370696e5f6e0000036f6e6500010a1a0213000340200041016b2100200041004a0d000b0b040041010b000d046e616d65030601000100016c",
  )
}

///|
/// A WASI plugin that writes 64 KiB to stdout in a loop that does not end.
/// ```wat
/// (module
///   (import "wasi_snapshot_preview1" "fd_write" (func $fd_write (param i32 i32 i32 i32) (result i32)))
///   (memory 2)
///   (func (export "flood") (result i32)
///     (i32.store (i32.const 0) (i32.const 1024))
///     (i32.store (i32.const 4) (i32.const 65536))
///     (loop $l
///       (drop (call $fd_write (i32.const 1) (i32.const 0) (i32.const 1) (i32.const 8)))
///       (br $l))
///     (i32.const 0)))
/// ```
pub fn wasi_flood() -> Bytes {
  hex(
    "0061736d01000000010d0260047f7f7f7f017f6000017f02230116776173695f736e617073686f745f70726576696577310866645f7772697465000003020101050301000207090105666c6f6f6400010a2701250041004180083602004104418080043602000340410141004101410810001a0c000b41000b001a046e616d65010b01000866645f7772697465030601010100016c",
  )
}

///|
/// A plugin that calls `http_request` with a handle outside kernel memory.
/// ```wat
/// (module
///   (import "extism:host/env" "http_request" (func $http_request (param i64 i64) (result i64)))
///   (func (export "bad_http") (result i32)
///     (drop (call $http_request (i64.const 0x7fffffff00) (i64.const 0)))
///     (i32.const 0)))
/// ```
pub fn http_bad_handle() -> Bytes {
  hex(
    "0061736d01000000010b0260027e7e017e6000017f0220010f65787469736d3a686f73742f656e760c687474705f72657175657374000003020101070c01086261645f6874747000010a120110004280feffffff0f420010001a41000b0016046e616d65010f01000c687474705f72657175657374",
  )
}
