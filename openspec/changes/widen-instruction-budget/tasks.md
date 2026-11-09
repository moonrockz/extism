# Tasks

## 1. A 64-bit instruction budget (morphir-ukvn.5.64.36.33)

- [x] 1.1 Write the failing tests: "Budget range" with 1, 2147483648, 5000000000, 9223372036854775807, 0 and -1,
  and "Budget above 2^31 on native", which measures the cost of the `spin_n` loop with small budgets and runs it
  above 2^31 with its exact budget and with 1 instruction less; verify that the second fails with the `int`
  counter of WAMR
- [x] 1.2 Add the "64-bit instruction counter" patch to `scripts/vendor-wamr.mbtx`, with a script test, and run
  `mise run vendor:wamr` on `WAMR-2.4.5` and SIMDe `v0.8.2`; verify that only the five patched files and
  `UPSTREAM.md` change and that `mise run check:wamr` passes
- [x] 1.3 Make `Budget` an `Int64` from 1 to 9223372036854775807, and send it to
  `wasm_runtime_set_instruction_count_limit64` as an `int64_t`; verify the tests pass on native, on js and with
  `mise run test:switch-dispatch`
- [x] 1.4 Compare the speed of a metered loop before and after the patch on macOS arm64
- [ ] 1.5 Run the Windows MSVC workflow on the branch; verify the engine tests pass with MSVC
- [x] 1.6 Update the engine README, the CHANGELOG (`Unreleased`, breaking) and the design
