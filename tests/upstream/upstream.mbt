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
  let digits = text.iter().filter(c => c != '\n').collect()
  Bytes::makei(digits.length() / 2, i => {
    (digit(digits[2 * i]) * 16 + digit(digits[2 * i + 1])).to_byte()
  })
}

///|
/// The upstream Extism kernel, checked against its pinned SHA-256.
pub fn upstream_kernel() -> Bytes {
  let bytes = hex(upstream_kernel_hex)
  guard @crypto.bytes_to_hex_string(@crypto.sha256(bytes)) ==
    "d1389b31abecf23eec65b4430d86f99f736aeb05c40948dbbe2f88cb17815803" else {
    abort("extism-runtime.wasm does not have its pinned SHA-256")
  }
  bytes
}

///|
/// The count-vowels plugin of extism/wamr-sdk, checked against its pinned SHA-256.
pub fn count_vowels() -> Bytes {
  let bytes = hex(count_vowels_hex)
  guard @crypto.bytes_to_hex_string(@crypto.sha256(bytes)) ==
    "4958d0e8a21a3f2c17605744ba5fc7e830e64d4b880489899c2a9333c72849ad" else {
    abort("count-vowels.wasm does not have its pinned SHA-256")
  }
  bytes
}
