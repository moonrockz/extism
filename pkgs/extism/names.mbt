///|
/// A value that breaks the rule of its type: the name of the type, the value and the rule.
pub(all) suberror NameError {
  NameError(String, String, String)
} derive(Eq, Debug)

///|
pub extend NameError with Eq::{equal, not_equal}

///|
pub extend NameError with @debug.Debug::{to_repr}

///|
/// The longest name that the library takes, in bytes of UTF-8.
let max_name_bytes : Int32 = 1024

///|
fn check_name(kind : String, text : String) -> Unit raise NameError {
  guard text != "" else { raise NameError(kind, text, "not empty") }
  guard @utf8.encode(text).length() <= max_name_bytes else {
    raise NameError(kind, text, "at most \{max_name_bytes} bytes of UTF-8")
  }
  guard !text.contains_char('\u{0}') else {
    raise NameError(kind, text, "no NUL character")
  }
}

///|
/// The import module name of a host function, for example `extism:host/user`.
pub struct Namespace {
  priv text : String
} derive(Eq, Debug)

///|
pub extend Namespace with Eq::{equal, not_equal}

///|
pub extend Namespace with @debug.Debug::{to_repr}

///|
/// A namespace: not empty, at most 1024 bytes and no NUL.
pub fn Namespace::parse(text : String) -> Namespace raise NameError {
  check_name("namespace", text)
  { text, }
}

///|
pub fn Namespace::text(self : Namespace) -> String {
  self.text
}

///|
/// The import field name of a host function, for example `lookup`.
pub struct FunctionName {
  priv text : String
} derive(Eq, Debug)

///|
pub extend FunctionName with Eq::{equal, not_equal}

///|
pub extend FunctionName with @debug.Debug::{to_repr}

///|
/// A function name: not empty, at most 1024 bytes and no NUL.
pub fn FunctionName::parse(text : String) -> FunctionName raise NameError {
  check_name("function name", text)
  { text, }
}

///|
pub fn FunctionName::text(self : FunctionName) -> String {
  self.text
}

///|
/// The name of a function that a plugin exports, for example `handle`.
pub struct ExportName {
  priv text : String
} derive(Eq, Debug)

///|
pub extend ExportName with Eq::{equal, not_equal}

///|
pub extend ExportName with @debug.Debug::{to_repr}

///|
/// An export name: not empty, at most 1024 bytes and no NUL.
pub fn ExportName::parse(text : String) -> ExportName raise NameError {
  check_name("export name", text)
  { text, }
}

///|
pub fn ExportName::text(self : ExportName) -> String {
  self.text
}

///|
/// A handle: the offset of a block in kernel memory. Zero is no block, so a handle is more than 0.
pub struct Handle {
  priv offset : Int64
} derive(Eq, Debug)

///|
pub extend Handle with Eq::{equal, not_equal}

///|
pub extend Handle with @debug.Debug::{to_repr}

///|
/// A handle: more than 0.
pub fn Handle::parse(offset : Int64) -> Handle raise NameError {
  guard offset > 0L else {
    raise NameError("handle", offset.to_string(), "more than 0")
  }
  { offset, }
}

///|
pub fn Handle::offset(self : Handle) -> Int64 {
  self.offset
}

///|
/// A number of bytes, from 0 to 2147483647.
pub struct ByteLimit {
  priv bytes : Int32
} derive(Eq, Debug)

///|
pub extend ByteLimit with Eq::{equal, not_equal}

///|
pub extend ByteLimit with @debug.Debug::{to_repr}

///|
/// A byte limit: from 0 to 2147483647 bytes.
pub fn ByteLimit::parse(bytes : Int64) -> ByteLimit raise NameError {
  guard bytes >= 0L && bytes <= 2147483647L else {
    raise NameError(
      "byte limit",
      bytes.to_string(),
      "from 0 to 2147483647 bytes",
    )
  }
  { bytes: bytes.to_int(), }
}

///|
pub fn ByteLimit::bytes(self : ByteLimit) -> Int32 {
  self.bytes
}
