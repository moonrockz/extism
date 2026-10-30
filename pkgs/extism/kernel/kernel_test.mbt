///|
fn kernel_type(type_ : @binary.ValType) -> @kernel.KernelType {
  match type_ {
    I32 => I32
    I64 => I64
    _ => abort("the kernel uses only i32 and i64")
  }
}

///|
test "Export signatures: each kernel function is exported with its upstream signature" {
  let module_ = @binary.Module::parse(@kernel.bytes())
  for function in @kernel.KernelFunction::all() {
    guard module_.export_type(function.name()) is Some(type_) else {
      fail("\{function.name()} is not exported")
    }
    assert_eq(type_.params.map(kernel_type), function.params())
    assert_eq(type_.results.map(kernel_type), function.results())
  }
  assert_eq(
    @kernel.KernelFunction::Alloc.params() +
    @kernel.KernelFunction::Alloc.results(),
    [I64, I64],
  )
  assert_eq(@kernel.KernelFunction::StoreU8.params(), [I64, I32])
  assert_eq(@kernel.KernelFunction::Reset.params(), [])
  assert_eq(@kernel.KernelFunction::Reset.results(), [])
}

///|
test "the kernel exports memory and the 20 functions only" {
  let module_ = @binary.Module::parse(@kernel.bytes())
  let names = module_.exports.map(e => e.name)
  names.sort()
  let expected = @kernel.KernelFunction::all().map(f => f.name())
  expected.push("memory")
  expected.sort()
  assert_eq(names, expected)
}

///|
test "Feature set of the kernel bytes: no imports, no feature, no extism_context" {
  let module_ = @binary.Module::parse(@kernel.bytes())
  assert_eq(module_.imports, [])
  assert_eq(module_.features(), [])
  assert_true(!module_.exports.iter().any(e => e.name == "extism_context"))
}

///|
test "No data and no stack: 16 initial pages, no data section, no global access" {
  let module_ = @binary.Module::parse(@kernel.bytes())
  assert_eq(module_.memories.length(), 1)
  assert_eq(module_.memories[0].min, 16L)
  assert_eq(module_.data_segment_count, 0)
  assert_true(!module_.sections.iter().any(s => s.id == 11))
  assert_false(module_.uses_globals())
}

///|
test "Same bytes on every target: the bytes give the embedded SHA-256" {
  assert_eq(sha256_hex(@kernel.bytes()), @kernel.sha256())
}

///|
test "from_name gives the function with that export name" {
  assert_eq(
    @kernel.KernelFunction::from_name("length_unsafe"),
    Some(LengthUnsafe),
  )
  assert_eq(@kernel.KernelFunction::from_name("extism_context"), None)
  assert_eq(@kernel.import_namespace, "extism:host/env")
}

///|
/// SHA-256 (FIPS 180-4), for the test that the embedded bytes have the embedded digest.
fn sha256_hex(data : Bytes) -> String {
  let k : FixedArray[UInt32] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4,
    0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe,
    0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f,
    0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc,
    0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
    0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116,
    0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7,
    0xc67178f2,
  ]
  let h : FixedArray[UInt32] = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab,
    0x5be0cd19,
  ]
  let length = data.length()
  let padded = (length + 9 + 63) / 64 * 64
  let message = FixedArray::make(padded, b'\x00')
  for i in 0..<length {
    message[i] = data[i]
  }
  message[length] = b'\x80'
  let bits = length.to_uint64() * 8
  for i in 0..<8 {
    message[padded - 1 - i] = (bits >> (8 * i)).to_byte()
  }
  let rotr = (x : UInt32, n : Int32) => (x >> n) | (x << (32 - n))
  let w = FixedArray::make(64, 0U)
  for chunk = 0; chunk < padded; chunk = chunk + 64 {
    for i in 0..<16 {
      w[i] = (message[chunk + 4 * i].to_uint() << 24) |
        (message[chunk + 4 * i + 1].to_uint() << 16) |
        (message[chunk + 4 * i + 2].to_uint() << 8) |
        message[chunk + 4 * i + 3].to_uint()
    }
    for i in 16..<64 {
      let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
      let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
      w[i] = w[i - 16] + s0 + w[i - 7] + s1
    }
    let v = h.copy()
    for i in 0..<64 {
      let s1 = rotr(v[4], 6) ^ rotr(v[4], 11) ^ rotr(v[4], 25)
      let choice = (v[4] & v[5]) ^ (v[4].lnot() & v[6])
      let t1 = v[7] + s1 + choice + k[i] + w[i]
      let s0 = rotr(v[0], 2) ^ rotr(v[0], 13) ^ rotr(v[0], 22)
      let majority = (v[0] & v[1]) ^ (v[0] & v[2]) ^ (v[1] & v[2])
      let t2 = s0 + majority
      v[7] = v[6]
      v[6] = v[5]
      v[5] = v[4]
      v[4] = v[3] + t1
      v[3] = v[2]
      v[2] = v[1]
      v[1] = v[0]
      v[0] = t1 + t2
    }
    for i in 0..<8 {
      h[i] = h[i] + v[i]
    }
  }
  let digits = "0123456789abcdef"
  let out = StringBuilder()
  for word in h {
    for shift = 28; shift >= 0; shift = shift - 4 {
      out.write_char(
        digits.get_char(((word >> shift) & 0xf).reinterpret_as_int()).unwrap(),
      )
    }
  }
  out.to_string()
}

///|
test "sha256_hex gives the FIPS 180-4 digest of abc" {
  assert_eq(
    sha256_hex(b"abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}
