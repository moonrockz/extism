///|
/// A WASM number type of a host import or an export.
pub(all) enum ValueType {
  I32
  I64
  F32
  F64
} derive(Eq, Debug)

///|
pub extend ValueType with Eq::{equal, not_equal}

///|
pub extend ValueType with @debug.Debug::{to_repr}

///|
/// A WASM number value.
pub(all) enum Value {
  I32(Int32)
  I64(Int64)
  F32(Float)
  F64(Double)
} derive(Eq, Debug)

///|
pub extend Value with Eq::{equal, not_equal}

///|
pub extend Value with @debug.Debug::{to_repr}

///|
/// The type of a value.
pub fn Value::value_type(self : Value) -> ValueType {
  match self {
    I32(_) => I32
    I64(_) => I64
    F32(_) => F32
    F64(_) => F64
  }
}

///|
/// The parameter and result types of a function.
pub(all) struct Signature {
  params : Array[ValueType]
  results : Array[ValueType]
} derive(Eq, Debug)

///|
pub extend Signature with Eq::{equal, not_equal}

///|
pub extend Signature with @debug.Debug::{to_repr}

///|
pub fn Signature::new(
  params : Array[ValueType],
  results : Array[ValueType],
) -> Signature {
  { params, results, }
}

///|
/// `(i64, i64) -> i64`, as WAT writes a signature.
pub impl Show for Signature with fn output(self, logger) {
  let name = (t : ValueType) => {
    match t {
      I32 => "i32"
      I64 => "i64"
      F32 => "f32"
      F64 => "f64"
    }
  }
  let results = match self.results {
    [] => "()"
    [one] => name(one)
    many => "(" + many.map(name).join(", ") + ")"
  }
  logger.write_string(
    "(" + self.params.map(name).join(", ") + ") -> " + results,
  )
}

///|
pub extend Signature with Show::{to_string, output}

///|
/// A limit value that breaks its rule: the name of the limit, the value and the rule.
pub suberror LimitError {
  LimitError(String, Int64, String)
}

///|
/// A number of 64 KiB pages of linear memory, from 1 to 65536.
pub struct PageCount {
  priv pages : Int32
} derive(Eq, Debug)

///|
pub extend PageCount with Eq::{equal, not_equal}

///|
pub extend PageCount with @debug.Debug::{to_repr}

///|
pub fn PageCount::parse(pages : Int32) -> PageCount raise LimitError {
  guard pages >= 1 && pages <= 65536 else {
    raise LimitError("page count", pages.to_int64(), "from 1 to 65536 pages")
  }
  { pages, }
}

///|
/// The default memory ceiling: 4096 pages (256 MiB).
pub fn PageCount::default_ceiling() -> PageCount {
  { pages: 4096, }
}

///|
pub fn PageCount::pages(self : PageCount) -> Int32 {
  self.pages
}

///|
/// An instruction budget for one call, from 1 to 2147483647 instructions (the C `int` of WAMR).
pub struct Budget {
  priv instructions : Int32
} derive(Eq, Debug)

///|
pub extend Budget with Eq::{equal, not_equal}

///|
pub extend Budget with @debug.Debug::{to_repr}

///|
pub fn Budget::parse(instructions : Int64) -> Budget raise LimitError {
  guard instructions >= 1L && instructions <= 2147483647L else {
    raise LimitError(
      "instruction budget", instructions, "from 1 to 2147483647 instructions",
    )
  }
  { instructions: instructions.to_int(), }
}

///|
pub fn Budget::instructions(self : Budget) -> Int32 {
  self.instructions
}

///|
/// A deadline for one call, in milliseconds, from 1 to 2147483647.
pub struct Deadline {
  priv milliseconds : Int32
} derive(Eq, Debug)

///|
pub extend Deadline with Eq::{equal, not_equal}

///|
pub extend Deadline with @debug.Debug::{to_repr}

///|
pub fn Deadline::parse(milliseconds : Int32) -> Deadline raise LimitError {
  guard milliseconds >= 1 else {
    raise LimitError(
      "deadline",
      milliseconds.to_int64(),
      "from 1 to 2147483647 milliseconds",
    )
  }
  { milliseconds, }
}

///|
pub fn Deadline::milliseconds(self : Deadline) -> Int32 {
  self.milliseconds
}

///|
/// A WASM feature beyond the core set that both engines take: WASM 1.0 with mutable globals, sign
/// extension, saturating conversions, multi-value, bulk memory and reference types.
pub(all) enum Feature {
  Simd
  Threads
  Memory64
  ExceptionHandling
  Gc
  TailCall
  MultiMemory
  Unknown(String)
} derive(Eq, Debug)

///|
pub extend Feature with Eq::{equal, not_equal}

///|
pub extend Feature with @debug.Debug::{to_repr}

///|
/// The name of a feature, for example `simd` or `exception-handling`.
pub fn Feature::name(self : Feature) -> String {
  match self {
    Simd => "simd"
    Threads => "threads"
    Memory64 => "memory64"
    ExceptionHandling => "exception-handling"
    Gc => "gc"
    TailCall => "tail-call"
    MultiMemory => "multi-memory"
    Unknown(what) => "unknown (\{what})"
  }
}

///|
fn Feature::of(feature : @binary.Feature) -> Feature {
  match feature {
    Simd => Simd
    Threads => Threads
    Memory64 => Memory64
    ExceptionHandling => ExceptionHandling
    Gc => Gc
    TailCall => TailCall
    MultiMemory => MultiMemory
    Unknown(what) => Unknown(what)
  }
}

///|
/// The features that a module needs, from a pure scan of its bytes. Both engines run this scan
/// before they compile.
pub fn Feature::scan(bytes : Bytes) -> Array[Feature] raise EngineError {
  let module_ = @binary.Module::parse(bytes) catch {
    DecodeError(at, rule) => raise Invalid("byte \{at}: \{rule}")
  }
  module_.features().map(Feature::of)
}

///|
/// Whether an engine enforces a bound.
pub(all) enum Bound {
  Enforced
  NotEnforced
} derive(Eq, Debug)

///|
pub extend Bound with Eq::{equal, not_equal}

///|
pub extend Bound with @debug.Debug::{to_repr}

///|
/// The bounds that an engine enforces.
pub(all) struct Bounds {
  memory : Bound
  budget : Bound
  interruption : Bound
} derive(Eq, Debug)

///|
pub extend Bounds with Eq::{equal, not_equal}

///|
pub extend Bounds with @debug.Debug::{to_repr}

///|
/// The kind of a trap.
pub(all) enum TrapKind {
  Unreachable
  MemoryOutOfBounds
  DivideByZero
  IntegerOverflow
  InvalidConversion
  StackExhausted
  IndirectCall
  TableOutOfBounds
  Host
  Other
} derive(Eq, Debug)

///|
pub extend TrapKind with Eq::{equal, not_equal}

///|
pub extend TrapKind with @debug.Debug::{to_repr}

///|
/// An error of a module load or an instantiation.
pub suberror EngineError {
  /// The bytes are not a valid module, with the reason.
  Invalid(String)
  /// The module needs a feature that the engine does not support.
  FeatureUnsupported(Feature)
  /// An import is missing or has another signature: the import and the detail.
  LinkError(String, String)
  /// The memory ceiling is smaller than the initial pages: the ceiling and the initial pages.
  CeilingBelowInitial(Int32, Int32)
  /// The start function of the module failed: a trap, an exhausted budget, an interruption, a memory
  /// limit or a host error.
  Start(CallError)
} derive(Debug)

///|
pub extend EngineError with @debug.Debug::{to_repr}

///|
/// The error of a host function, with its message.
pub(all) suberror HostError {
  HostError(String)
} derive(Eq, Debug)

///|
pub extend HostError with Eq::{equal, not_equal}

///|
pub extend HostError with @debug.Debug::{to_repr}

///|
/// An error of a call.
pub(all) suberror CallError {
  /// The guest trapped.
  Trap(TrapKind)
  /// The call ran more instructions than its budget.
  BudgetExhausted
  /// The call passed its deadline.
  Interrupted
  /// The call failed after the ceiling refused a `memory.grow`.
  MemoryLimit
  /// A host function failed.
  Host(HostError)
  /// The instance exports no function with this name.
  UnknownExport(String)
  /// The arguments do not match the signature of the export: the export and the detail.
  ArgumentMismatch(String, String)
  /// An earlier call trapped, so the instance takes no more calls.
  Unusable
} derive(Debug)

///|
pub extend CallError with @debug.Debug::{to_repr}

///|
/// A guest memory access that is outside the memory: the offset and the length.
pub(all) suberror MemoryError {
  OutOfBounds(Int64, Int32)
} derive(Eq, Debug)

///|
pub extend MemoryError with Eq::{equal, not_equal}

///|
pub extend MemoryError with @debug.Debug::{to_repr}

///|
/// The kind and the type of an import or an export.
pub(all) enum ExternKind {
  /// A function; `None` when its signature has a type other than the four number types.
  Function(Signature?)
  Table
  Memory
  Global
  Tag
} derive(Eq, Debug)

///|
pub extend ExternKind with Eq::{equal, not_equal}

///|
pub extend ExternKind with @debug.Debug::{to_repr}

///|
pub(all) struct ImportDescriptor {
  module_ : String
  name : String
  kind : ExternKind
} derive(Eq, Debug)

///|
pub extend ImportDescriptor with Eq::{equal, not_equal}

///|
pub extend ImportDescriptor with @debug.Debug::{to_repr}

///|
pub(all) struct ExportDescriptor {
  name : String
  kind : ExternKind
} derive(Eq, Debug)

///|
pub extend ExportDescriptor with Eq::{equal, not_equal}

///|
pub extend ExportDescriptor with @debug.Debug::{to_repr}
