# moonrockz/extism

Read `README.md` for the layout and the tasks, and `CONTEXT.md` for the vocabulary.
moonrockz/extism is an Extism host for MoonBit. It is a general library: it has no Morphir concepts.
`finos/morphir-moonbit` is its first consumer and registers its own host functions through the plugin API.

## Planning and specifications

- Follow `CONTRIBUTING.md`. A change to behavior, a public API or a requirement starts as an OpenSpec
  change in `openspec/changes/`, with the `html-design` schema.
- Work is tracked in the **shared Morphir beads tracker** (`bd`), with the label `repo:extism`. This
  repository has no beads database: do not run `bd init` here, and do not commit `.beads/`. Run `bd`
  from a checkout that is set up for the shared tracker, for example finos/morphir-moonbit.
- Each task group in a change's `tasks.md` is one bead; its heading ends with the bead ID. Tick the
  tasks in `tasks.md` in the pull request. A coordinator closes the beads after the merge.
- Run `mise run openspec:validate` after you edit `openspec/`.

### Specs and plans are HTML documents

The OpenSpec `proposal.md`, `tasks.md` and `spec.md` files stay Markdown, because the `openspec` CLI
parses them. The design is `design.html`, a copy of `docs/templates/agent-document.html`:

- Keep its `<head>` as it is. It references the styles and scripts in `docs/templates/assets/` by
  relative paths that are correct from `openspec/changes/<name>/`. Add no `<style>` element, no
  inline script, no other script and no external resource.
- `docs/templates/assets/highlight/` holds highlight.js 11.12.0 from `@highlightjs/cdn-assets`, with
  its license. `UPSTREAM.md` records the hashes.
- Put code in `<pre><code class="language-moonbit">` (also `zig`, `c`, `toml`, `json`, `bash`,
  `diff`). Escape `<`, `>` and `&`. Give every section an `id` and list it in `nav.toc`.
- The schema and the template come from finos/morphir-moonbit (`openspec/schemas/html-design/` and
  `docs/templates/`). The only local change is the beads label `repo:extism` in `schema.yaml`. Copy
  upstream changes from there.
- The generated `openspec-*` skills say `design.md`; in this repository that file is `design.html`.

## Toolchain and tasks

- Pin tools in `.config/mise/config.toml`. MoonBit and Zig use the pins of finos/morphir-moonbit, so
  the consumer builds the native engine with the same Zig. Run `mise trust` and `mise install`.
- Write automation in `scripts/*.mbtx`, run with `moonx`, and expose it as mise tasks through
  `scripts/toolchain.mbtx`. Pin each import. Do not add shell, PowerShell, Python or JavaScript task
  scripts, and do not move task logic into workflow shell blocks.
- Use `moonbitlang/async` for process, file and stdio work in scripts and drivers, and
  `moonbitlang/x/sys` for `exit`.
- Put libraries under `pkgs/` and executables under `apps/`. Register each module in `moon.work`.
  `mise run validate` checks the members, the versions and the `private` flags.
- The root `moon.mod` is the version source of truth. Every member has the same version.

## MoonBit code

- **Functional core, imperative shell.** Keep validation, decisions and state transitions pure.
  Decode external bytes, strings and JSON into domain values at the boundary. Keep engine calls,
  file, process and host effects in adapters.
- **Closed enums and validated value types.** Do not use a raw `String`, `Int`, `Array` or `Map` for a
  value with rules, for example an export name, a namespace, a page count, a byte limit, an
  instruction budget, a handle or a WASI errno. Give each type a smart constructor with private
  fields, for example `PageCount::parse(n) -> PageCount raise LimitError`. Use an enum for a fixed set
  of cases. A parse failure is a typed `suberror` that names the input and the rule.
- **Subject-first public functions.** Write a public operation as a method of its subject,
  `Plugin::call(self, name, input)`, not as a free function that takes the subject last.
- **Pipes and method chains.** Prefer `bytes |> Module::parse` and `items.iter().filter(...).map(...)`
  to nested calls and temporary variables.
- Test each rule of a smart constructor with values on each side of the limit. Write the failing
  test first.
- Library code builds and tests on its declared targets: `kernel` and `wasi` on `wasm`, `wasm-gc`,
  `js` and `native`; `engine` and the plugin API on `native` and `js`. A `supported_targets` or
  `warnings` setting in `moon.pkg` has a comment that gives the reason.
- Clear every warning in the modules that you touch. `mise run lint` runs `moon check --deny-warn`.

## Command output for automation

Every program under `apps/` and every command that a published package gives supports an opt-in
`--json` flag:

- A finite command in JSON mode writes one JSON document to stdout, with `command`, `state`
  (`succeeded` or `failed`), `exitCode`, `diagnostics`, and `result` on success or
  `error: {code, message}` on failure. Progress, diagnostics and child output go to stderr.
- A command that serves until a signal stops it, such as `site serve`, has no finite result and does
  not take `--json`.
- Do not put JSON into a protocol channel that a host owns, for example plugin input and output bytes.

Task scripts in `scripts/` report through their exit status (0 success, 1 failure, 2 usage) and are
not commands in this sense.

## Verification

Run `mise run check` after changes. It runs lint, validate, OpenSpec validation, tests on the four
targets, task script tests, builds and the docs site. Install the hooks with `mise run hooks:install`:
pre-commit runs `lint:moonbit --staged`, pre-push runs lint, validate, test, `test:scripts` and
`openspec:validate`. Never push with `--no-verify`. Run `mise run format` before you commit MoonBit
changes, and commit the `pkg.generated.mbti` files that `mise run lint` writes.

## Commits and pull requests

Use Conventional Commits in plain English. Do not add AI attribution lines, `Co-Authored-By` lines or
"Generated with" footers to commits, pull requests or issues.

## Review guidelines

The review checklist is the skill `.agents/skills/code-review/SKILL.md`. It is the one source for
every agent tool: the `code-reviewer` agents in `.claude/agents/`, `.cursor/agents/`,
`.codex/agents/` and `.github/agents/` only point to it. Change the checklist only in the skill.

## Publishing

`moonrockz/extism` in `pkgs/extism/` is the only published module. The workspace root and
`apps/site` are private. Ask the maintainer before a release or a Mooncakes publication; never publish
from a workstation, and never move a tag.
