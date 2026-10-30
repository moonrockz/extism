///|
/// A WASM value type. `Other` holds the code of a type that the engines do not take, such as a typed
/// reference of the GC proposal.
pub(all) enum ValType {
  I32
  I64
  F32
  F64
  V128
  FuncRef
  ExternRef
  Other(Int32)
} derive(Eq, Debug)

///|
pub extend ValType with Eq::{equal, not_equal}

///|
pub extend ValType with @debug.Debug::{to_repr}

///|
/// A function type.
pub(all) struct FuncType {
  params : Array[ValType]
  results : Array[ValType]
} derive(Eq, Debug)

///|
pub extend FuncType with Eq::{equal, not_equal}

///|
pub extend FuncType with @debug.Debug::{to_repr}

///|
/// The limits of a memory or a table, in pages or elements.
pub(all) struct Limits {
  min : Int64
  max : Int64?
  shared : Bool
  is64 : Bool
} derive(Eq, Debug)

///|
pub extend Limits with Eq::{equal, not_equal}

///|
pub extend Limits with @debug.Debug::{to_repr}

///|
/// The type of an import.
pub(all) enum ImportType {
  Func(FuncType)
  Table
  Memory(Limits)
  Global
  Tag
} derive(Eq, Debug)

///|
pub extend ImportType with Eq::{equal, not_equal}

///|
pub extend ImportType with @debug.Debug::{to_repr}

///|
pub(all) struct Import {
  module_ : String
  name : String
  type_ : ImportType
} derive(Eq, Debug)

///|
pub extend Import with Eq::{equal, not_equal}

///|
pub extend Import with @debug.Debug::{to_repr}

///|
pub(all) enum ExportKind {
  Func
  Table
  Memory
  Global
  Tag
} derive(Eq, Debug)

///|
pub extend ExportKind with Eq::{equal, not_equal}

///|
pub extend ExportKind with @debug.Debug::{to_repr}

///|
pub(all) struct Export {
  name : String
  kind : ExportKind
  index : Int32
} derive(Eq, Debug)

///|
pub extend Export with Eq::{equal, not_equal}

///|
pub extend Export with @debug.Debug::{to_repr}

///|
/// A WASM feature beyond the core set that the engines take (WASM 1.0 with sign extension,
/// saturating conversions, multi-value, bulk memory and reference types).
pub(all) enum Feature {
  Simd
  Threads
  Memory64
  ExceptionHandling
  Gc
  TailCall
  Unknown(String)
} derive(Eq, Debug)

///|
pub extend Feature with Eq::{equal, not_equal}

///|
pub extend Feature with @debug.Debug::{to_repr}

///|
/// A section: its id and the range of its payload in the module bytes.
pub(all) struct Section {
  id : Int32
  start : Int32
  end : Int32
} derive(Eq, Debug)

///|
pub extend Section with Eq::{equal, not_equal}

///|
pub extend Section with @debug.Debug::{to_repr}

///|
/// The body of one function in the code section: the range of its bytes after the size.
priv struct Body {
  start : Int32
  end : Int32
}

///|
/// The parts of a module that the engines and the plugin API need. A module with a feature that the
/// reader cannot follow (for example GC types) gives the feature and stops reading that section.
pub struct Module {
  bytes : Bytes
  sections : Array[Section]
  types : Array[FuncType]
  imports : Array[Import]
  /// The type index of each function that the module defines.
  functions : Array[Int32]
  memories : Array[Limits]
  global_count : Int32
  exports : Array[Export]
  data_segment_count : Int32
  priv bodies : Array[Body]
  priv features : Array[Feature]
}

///|
fn add_feature(features : Array[Feature], feature : Feature) -> Unit {
  if !features.contains(feature) {
    features.push(feature)
  }
}

///|
fn Reader::val_type(
  self : Reader,
  features : Array[Feature],
) -> ValType raise DecodeError {
  match self.byte() {
    0x7f => I32
    0x7e => I64
    0x7d => F32
    0x7c => F64
    0x7b => {
      add_feature(features, Simd)
      V128
    }
    0x70 => FuncRef
    0x6f => ExternRef
    code => {
      add_feature(features, Gc)
      // A typed reference has a heap type after its code.
      if code == 0x64 || code == 0x63 {
        self.skip_signed()
      }
      Other(code)
    }
  }
}

///|
fn Reader::limits(
  self : Reader,
  features : Array[Feature],
) -> Limits raise DecodeError {
  let flags = self.byte()
  guard flags <= 0x07 else {
    add_feature(features, Unknown("limits flags \{flags}"))
    raise self.fail("limits flags \{flags} are not known")
  }
  let shared = (flags & 0x02) != 0
  let is64 = (flags & 0x04) != 0
  if shared {
    add_feature(features, Threads)
  }
  if is64 {
    add_feature(features, Memory64)
  }
  let bits = if is64 { 64 } else { 32 }
  let min = self.unsigned(bits~)
  let max = if (flags & 0x01) != 0 { Some(self.unsigned(bits~)) } else { None }
  { min, max, shared, is64, }
}

///|
fn Reader::func_type(
  self : Reader,
  features : Array[Feature],
) -> FuncType raise DecodeError {
  let params = Array::makei(self.count(), _ => self.val_type(features))
  let results = Array::makei(self.count(), _ => self.val_type(features))
  { params, results, }
}

///|
/// Reads the module `bytes`.
pub fn Module::parse(bytes : Bytes) -> Module raise DecodeError {
  guard bytes.length() >= 8 &&
    bytes[0] == b'\x00' &&
    bytes[1] == b'\x61' &&
    bytes[2] == b'\x73' &&
    bytes[3] == b'\x6d' else {
    raise DecodeError(0, "the bytes are not a WASM module")
  }
  guard bytes[4] == b'\x01' &&
    bytes[5] == b'\x00' &&
    bytes[6] == b'\x00' &&
    bytes[7] == b'\x00' else {
    raise DecodeError(
      4, "the WASM version is not 1 (a component is not a module)",
    )
  }
  let reader = Reader::new(bytes, 8, bytes.length())
  let sections = []
  let types = []
  let imports = []
  let functions = []
  let memories = []
  let exports = []
  let bodies = []
  let features = []
  let mut global_count = 0
  let mut data_segment_count = 0
  while !reader.done() {
    let id = reader.byte()
    let size = reader.u32()
    let start = reader.at
    reader.skip(size)
    sections.push({ id, start, end: start + size, })
    let section = Reader::new(bytes, start, start + size)
    match id {
      1 =>
        for _ in 0..<section.count() {
          let form = section.byte()
          guard form == 0x60 else {
            // A recursive or sub type of the GC proposal.
            add_feature(features, Gc)
            break
          }
          types.push(section.func_type(features))
        }
      2 =>
        for _ in 0..<section.count() {
          let module_ = section.name()
          let name = section.name()
          let type_ = match section.byte() {
            0x00 => {
              let index = section.u32()
              guard index < types.length() else {
                raise section.fail(
                  "import \{module_}.\{name} has an unknown type",
                )
              }
              ImportType::Func(types[index])
            }
            0x01 => {
              section.val_type(features) |> ignore
              section.limits(features) |> ignore
              Table
            }
            0x02 => Memory(section.limits(features))
            0x03 => {
              section.val_type(features) |> ignore
              section.byte() |> ignore
              Global
            }
            0x04 => {
              add_feature(features, ExceptionHandling)
              section.byte() |> ignore
              section.u32() |> ignore
              Tag
            }
            kind => raise section.fail("import kind \{kind} is not known")
          }
          imports.push({ module_, name, type_, })
        }
      3 =>
        for _ in 0..<section.count() {
          functions.push(section.u32())
        }
      4 =>
        for _ in 0..<section.count() {
          section.val_type(features) |> ignore
          section.limits(features) |> ignore
        }
      5 =>
        for _ in 0..<section.count() {
          memories.push(section.limits(features))
        }
      6 => {
        let count = section.count()
        global_count = count
        for _ in 0..<count {
          section.val_type(features) |> ignore
          section.byte() |> ignore
          section.expression(features)
        }
      }
      7 =>
        for _ in 0..<section.count() {
          let name = section.name()
          let kind : ExportKind = match section.byte() {
            0x00 => Func
            0x01 => Table
            0x02 => Memory
            0x03 => Global
            0x04 => Tag
            kind => raise section.fail("export kind \{kind} is not known")
          }
          exports.push({ name, kind, index: section.u32(), })
        }
      10 =>
        for _ in 0..<section.count() {
          let body_size = section.u32()
          let body_start = section.at
          section.skip(body_size)
          bodies.push({ start: body_start, end: body_start + body_size, })
        }
      11 => data_segment_count = section.u32()
      13 => add_feature(features, ExceptionHandling)
      _ => ()
    }
  }
  let module_ = {
    bytes,
    sections,
    types,
    imports,
    functions,
    memories,
    global_count,
    exports,
    data_segment_count,
    bodies,
    features,
  }
  module_.scan_code()
  module_
}

///|
/// Reads a constant expression up to its `end`.
fn Reader::expression(
  self : Reader,
  features : Array[Feature],
) -> Unit raise DecodeError {
  let scan = Scan::new()
  while true {
    let opcode = self.byte()
    if opcode == 0x0b {
      break
    }
    guard self.instruction(opcode, scan) else {
      features.append(scan.features)
      // The rest of the expression cannot be followed.
      raise self.fail("constant expression uses an unknown instruction")
    }
  }
  for feature in scan.features {
    add_feature(features, feature)
  }
}

///|
/// The features that the module needs, in the order that the reader found them.
pub fn Module::features(self : Module) -> Array[Feature] {
  self.features.copy()
}

///|
/// The number of functions that the module imports.
pub fn Module::imported_function_count(self : Module) -> Int32 {
  self.imports.iter().filter(i => i.type_ is Func(_)).count()
}

///|
/// The number of globals that the module imports.
pub fn Module::imported_global_count(self : Module) -> Int32 {
  self.imports.iter().filter(i => i.type_ is Global).count()
}

///|
/// The type of the function with index `index` in the function index space (imports first).
pub fn Module::function_type(self : Module, index : Int32) -> FuncType? {
  let imported = self.imports.filter_map(i => {
    match i.type_ {
      Func(type_) => Some(type_)
      _ => None
    }
  })
  if index < 0 {
    None
  } else if index < imported.length() {
    Some(imported[index])
  } else if index - imported.length() < self.functions.length() {
    self.types.get(self.functions[index - imported.length()])
  } else {
    None
  }
}

///|
/// The type of the exported function `name`, or `None` when the module exports no function with
/// that name.
pub fn Module::export_type(self : Module, name : String) -> FuncType? {
  match self.exports.iter().find_first(e => e.name == name && e.kind == Func) {
    Some(found) => self.function_type(found.index)
    None => None
  }
}

///|
/// The limits of the memory that the module defines or imports, or `None` when it has none.
pub fn Module::memory(self : Module) -> Limits? {
  match self.imports.iter().find_first(i => i.type_ is Memory(_)) {
    Some({ type_: Memory(limits), .. }) => Some(limits)
    _ => self.memories.get(0)
  }
}

///|
/// Whether the module imports its memory.
pub fn Module::imports_memory(self : Module) -> Bool {
  self.imports.iter().any(i => i.type_ is Memory(_))
}
