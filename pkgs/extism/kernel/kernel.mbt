///|
/// The import namespace of the kernel functions in a plugin.
pub let import_namespace : String = "extism:host/env"

///|
/// A WASM value type of the kernel ABI. The kernel uses no other type.
pub(all) enum KernelType {
  I32
  I64
} derive(Eq, Debug)

///|
pub extend KernelType with Eq::{equal, not_equal}

///|
pub extend KernelType with @debug.Debug::{to_repr}

///|
/// The 20 functions of the upstream Extism kernel, which the kernel module exports with their upstream
/// names and signatures.
pub(all) enum KernelFunction {
  Alloc
  Free
  Length
  LengthUnsafe
  LoadU8
  LoadU64
  InputLoadU8
  InputLoadU64
  StoreU8
  StoreU64
  InputSet
  OutputSet
  InputLength
  InputOffset
  OutputLength
  OutputOffset
  Reset
  ErrorSet
  ErrorGet
  MemoryBytes
} derive(Eq, Debug)

///|
pub extend KernelFunction with Eq::{equal, not_equal}

///|
pub extend KernelFunction with @debug.Debug::{to_repr}

///|
/// Every kernel function, in the upstream order of the exports.
pub fn KernelFunction::all() -> Array[KernelFunction] {
  [
    Alloc,
    Free,
    LengthUnsafe,
    Length,
    LoadU8,
    LoadU64,
    InputLoadU8,
    InputLoadU64,
    StoreU8,
    StoreU64,
    InputSet,
    OutputSet,
    InputLength,
    InputOffset,
    OutputLength,
    OutputOffset,
    Reset,
    ErrorSet,
    ErrorGet,
    MemoryBytes,
  ]
}

///|
/// The export name of a kernel function, for example `alloc` or `length_unsafe`.
pub fn KernelFunction::name(self : KernelFunction) -> String {
  match self {
    Alloc => "alloc"
    Free => "free"
    Length => "length"
    LengthUnsafe => "length_unsafe"
    LoadU8 => "load_u8"
    LoadU64 => "load_u64"
    InputLoadU8 => "input_load_u8"
    InputLoadU64 => "input_load_u64"
    StoreU8 => "store_u8"
    StoreU64 => "store_u64"
    InputSet => "input_set"
    OutputSet => "output_set"
    InputLength => "input_length"
    InputOffset => "input_offset"
    OutputLength => "output_length"
    OutputOffset => "output_offset"
    Reset => "reset"
    ErrorSet => "error_set"
    ErrorGet => "error_get"
    MemoryBytes => "memory_bytes"
  }
}

///|
/// The kernel function with the export name `name`, or `None` when no kernel function has that name.
pub fn KernelFunction::from_name(name : StringView) -> KernelFunction? {
  KernelFunction::all()
  .iter()
  .find_first(function => function.name() == name.to_owned())
}

///|
/// The parameter types of a kernel function.
pub fn KernelFunction::params(self : KernelFunction) -> Array[KernelType] {
  match self {
    Alloc
    | Free
    | Length
    | LengthUnsafe
    | LoadU8
    | LoadU64
    | InputLoadU8
    | InputLoadU64
    | ErrorSet => [I64]
    StoreU8 => [I64, I32]
    StoreU64 | InputSet | OutputSet => [I64, I64]
    InputLength
    | InputOffset
    | OutputLength
    | OutputOffset
    | Reset
    | ErrorGet
    | MemoryBytes => []
  }
}

///|
/// The result types of a kernel function.
pub fn KernelFunction::results(self : KernelFunction) -> Array[KernelType] {
  match self {
    LoadU8 | InputLoadU8 => [I32]
    Alloc
    | Length
    | LengthUnsafe
    | LoadU64
    | InputLoadU64
    | InputLength
    | InputOffset
    | OutputLength
    | OutputOffset
    | ErrorGet
    | MemoryBytes => [I64]
    Free | StoreU8 | StoreU64 | InputSet | OutputSet | Reset | ErrorSet => []
  }
}

///|
fn decode_hex(text : String) -> Bytes {
  let digit = (c : Char) => {
    let code = c.to_int()
    if code >= '0'.to_int() && code <= '9'.to_int() {
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
let kernel_bytes : Bytes = decode_hex(kernel_hex)

///|
/// The kernel module: one `wasm32-freestanding` module built from the Zig source in `kernel/`.
pub fn bytes() -> Bytes {
  kernel_bytes
}

///|
/// The SHA-256 of the kernel module, in lowercase hex.
pub fn sha256() -> String {
  kernel_sha256
}
