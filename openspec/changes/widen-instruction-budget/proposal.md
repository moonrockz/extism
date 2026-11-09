# Proposal

## Why

The native engine refuses an instruction budget above 2147483647, because WAMR holds the instruction limit in a C
`int`. The Morphir model line in `finos/morphir-moonbit` needs 5,000,000,000 instructions for one WASM call on a
large model. Upstream WAMR has no 64-bit counter and no API that refills the counter: at `WAMR-2.4.5` and at
`main` `ffc22889948b1f063d7258d34d4e636ee0914925` (2026-11-06) the counter is an `int`, and pull request #4902
(resume after the limit) is open and not merged.

## What Changes

- **Vendored WAMR.** A small patch makes the instruction counter of the execution environment and of the fast
  interpreter a 64-bit integer, and adds `wasm_runtime_set_instruction_count_limit64`. The `int` function stays as
  it is. `scripts/vendor-wamr.mbtx` holds the patch, so a new vendor run keeps it, and `UPSTREAM.md` records it.
- **Engine (`moonrockz/extism/engine`).** `Budget::parse` accepts 1 to 9223372036854775807 instructions (the
  `Int64` maximum). `Budget::instructions` returns `Int64`, not `Int32`. The native engine sends the budget to WAMR
  as an `int64_t` on every platform, also on Windows, where a C `long` has 32 bits.
- **BREAKING:** `Budget::instructions` returns `Int64`. The next release is 0.3.0. A caller that only uses
  `Budget::parse` does not change.

Out of scope:

- A budget on js. The js engine does not meter instructions, as before.
- A budget that adds up across calls, or across host re-entries into the guest. WAMR reads the limit when a call
  enters the interpreter (upstream issue #5139); the engine does not change this.
- The classic interpreter, AOT and JIT. The engine builds the fast interpreter only.
- An upstream pull request to bytecodealliance/wasm-micro-runtime. It needs the maintainer's approval first.
- The change in `finos/morphir-moonbit` (`CallBounds.instructions` as `Int64`, the model-line budget). It is a
  separate pull request after the release.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `wasm-engine`: the requirement "Instruction budget" gets the range 1 to 9223372036854775807 and a scenario for
  a budget above 2^31.

## Beads

- **Tracked by**: `morphir-ukvn.5.64.36.33` (shared Morphir tracker, label `repo:extism`)
- **Related**:
  - `morphir-ukvn.5.64.36` (parent epic: host extensions as MEP workers in the MoonBit CLI)
  - `morphir-ukvn.5.64.36.26` (the model-line budget of 5,000,000,000 instructions that needs this change)

## Impact

- **Code:** `pkgs/extism/engine/types.mbt`, `native.mbt`, `wamr/extism_engine.c`, five vendored WAMR files,
  `scripts/vendor-wamr.mbtx`, and the tests.
- **API:** `Budget::instructions` returns `Int64` (breaking). `Budget::parse` keeps its signature.
- **Speed:** no measured change. A loop of 700,000,000 iterations took 1506 to 1576 ms before and 1513 to 1537 ms
  after, on macOS arm64.
- **Consumers:** `finos/morphir-moonbit` calls only `Budget::parse`, so it builds with no code change.
