---
name: code-review
description: Review a moonrockz/extism diff, branch or pull request against the repository practices in AGENTS.md. Checks domain types (no primitive obsession; parse, do not validate; smart constructors), pure domain code, I/O boundaries, the sandbox and capability rules of the plugin API, OpenSpec agreement, targets, warnings and generated interfaces. Use after a change and before a pull request. Reports findings and does not edit files.
---

# Code review

Use this skill to review a change to moonrockz/extism, an Extism host for MoonBit. The review does
not edit files. It reports findings that the author can act on.

This file is the one checklist for every agent tool. The tool wrappers in `.claude/agents/`,
`.cursor/agents/`, `.codex/agents/` and `.github/agents/` only point here. Change the checklist here,
not in a wrapper.

## Start

1. Read `AGENTS.md` and `CONTRIBUTING.md`. Their rules are the standard for the review. When this
   file and `AGENTS.md` disagree, `AGENTS.md` wins.
2. Find the change. Use the target that the caller gives. Else review `git diff origin/main...HEAD`
   and the uncommitted changes.
3. When the change belongs to an OpenSpec change, read its `proposal.md`, `design.html`, `tasks.md`
   and the spec deltas in `openspec/changes/<name>/`.
4. Read the full changed files, not only the diff lines, before you report a finding.
5. Vendored upstream code (for example WAMR C source) is out of scope for the checklist. Review only
   its difference from the pinned upstream release.

Use the compiler for mechanical questions. You can run `moon check --deny-warn --target all`,
`moon test` with a target, `zig build test` for Zig code, and `mise exec -- openspec validate --all
--strict`. Do not run commands that write to the repository, push, or change the tracker.

## Checklist

### Domain types (highest priority)

- A public function, field or step that takes or holds a raw `String`, `Int`, `Array` or `Map` for a
  value with rules: an export name, a namespace, a page count, a byte limit, an instruction budget, a
  handle, a deadline, a WASI errno. If the value has rules, it needs a type.
- A `pub(all)` struct, a public tuple struct or public fields that let a caller make a value that
  breaks its rules.
- A smart constructor that is missing or can be bypassed: the type has private fields and one parse
  function that raises a typed `suberror`.
- Validation in place of a parse, or the same rule checked at more than one place.
- A string or an integer code where a closed enum fits, for example an engine feature or an error kind.
- A missing test for each rule of a smart constructor, on each side of the limit.

### Sandbox and capabilities

- A host function, WASI function or kernel binding that gives a plugin an authority that the
  embedder's policy did not grant: files, network, clock, random bytes, environment, process.
- A WASI preview 1 function that is not linked, or that does something other than its documented
  sandbox answer.
- A limit (memory ceiling, instruction budget, deadline, output size) that a plugin can pass, or a
  bound that is reported as enforced on an engine that does not enforce it.
- Kernel bytes that differ from a fresh build of the Zig source.

### Purity and boundaries

- I/O outside host adapters and drivers. Process and file work uses `moonbitlang/async`. Engine
  bindings use C stubs on native and `extern "js"` on js, and nothing else.
- Domain functions that read hidden state, such as the process environment, the clock or the working
  directory, in place of explicit inputs.
- Public values that can change after construction.
- Morphir concepts in this repository. The library is general; Morphir registers its own host functions.

### Public API and interfaces

- A changed public API without its updated `pkg.generated.mbti`.
- A public item without a doc comment, or a doc comment that disagrees with the behavior.
- An API that disagrees with the design or spec of its OpenSpec change.

### Targets and warnings

- Library code that does not build and test on its declared targets: `kernel` and `wasi` on `wasm`,
  `wasm-gc`, `js` and `native`; `engine` and the plugin API on `native` and `js`.
- A `supported_targets` or `warnings` setting in `moon.pkg` without a comment that gives the reason.

### Errors and exit codes

- An error matched by its message text. Errors are typed values.
- An `abort` or `panic` for a fault that a plugin or an input can cause.

### Specs, tasks and docs

- Behavior, a public API or a requirement that changes without an OpenSpec change.
- A ticked task in `tasks.md` whose behavior or test is missing.
- Documentation and comments that do not use ASD-STE100 Simplified Technical English, or README
  examples that the tests do not compile. Package README examples go in `README.mbt.md` files.

### Commits

- A commit message that is not a Conventional Commit, or one with an AI attribution line.

## Report

Give findings in order of severity. For each finding give:

- `path:line`
- The rule from the checklist or from `AGENTS.md`
- The problem in one sentence, and a concrete case where it fails or misleads
- The fix

Mark each finding as confirmed (you read the code or ran the check) or as a question (you need the
author's intent). Do not praise and do not list style points that the formatter or the linter
already checks. If you find nothing, say so in one line.
