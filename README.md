# moonrockz/extism

An [Extism](https://extism.org) host for MoonBit. A MoonBit program on native, Node.js or a browser
loads an Extism plugin, calls its exports and gets the results, with limits on memory and time.

> [!NOTE]
> No version is published yet. The OpenSpec change
> [`host-extism-plugins`](openspec/changes/host-extism-plugins/) gives the requirements and the design.

## Packages

The library is one module, `moonrockz/extism`, in `pkgs/extism/`.

| Package | Gives | Targets |
| --- | --- | --- |
| `moonrockz/extism` | The plugin API: manifest, Extism host functions with an embedder policy, host functions that the embedder registers in any namespace, call by export name, limits | native, js |
| `moonrockz/extism/kernel` | The Extism kernel, written in Zig and compiled to one `wasm32-freestanding` module, embedded as bytes | all |
| `moonrockz/extism/wasi` | A WASI preview 1 sandbox: no preopens, empty arguments, environment and stdin, clocks and random bytes from the embedder, stdout and stderr to the embedder, an error code for all other functions | all |
| `moonrockz/extism/engine` | A small WASM engine layer: compile, instantiate with host imports, call an export, memory ceiling, instruction budget, interruption, named feature errors | native, js |

On native, the engine is the WAMR fast interpreter, built from C source with Zig. On js, the engine
uses the `WebAssembly` API of Node.js or of the browser.

## Repository layout

| Path | Contents |
| --- | --- |
| `pkgs/extism/` | The library module `moonrockz/extism` |
| `apps/site/` | The docs site driver, over [`moonrockz/telescope`](https://github.com/moonrockz/telescope); not published |
| `docs/`, `site/` | The docs site content and its configuration |
| `docs/templates/` | The HTML document template that OpenSpec designs use |
| `openspec/` | Requirements and change proposals, with the `html-design` schema |
| `scripts/` | Task scripts in MoonBit (`.mbtx`), run with `moonx` |

## Development setup

The tools are pinned in `.config/mise/config.toml`: MoonBit, Zig, Node.js, OpenSpec, yamllint,
actionlint and lefthook.

```shell
mise trust
mise install
# The MoonBit archive that mise installs has no core library and no moonx. Complete it:
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | \
  MOON_HOME="$(mise where http:moonbit)" bash -s -- "$(mise current http:moonbit)"
mise run hooks:install
```

On Windows, run the official `powershell.ps1` installer with `MOON_HOME` set to
`mise where http:moonbit` and `MOONBIT_INSTALL_VERSION` set to `mise current http:moonbit`.

## Tasks

| Task | Does |
| --- | --- |
| `mise run check` | Every check: lint, validate, the vendored WAMR check, OpenSpec, tests, task script tests, builds and the site |
| `mise run lint` | YAML and workflow lint, MoonBit format check, `moon check --deny-warn` and interface check |
| `mise run validate` | Workspace members, versions and publication flags |
| `mise run test [-- <target>...]` | Tests on `wasm`, `wasm-gc`, `js` and `native` |
| `mise run test:scripts` | Tests of the task scripts |
| `mise run build [-- <target>... --release]` | Builds of every workspace member |
| `mise run format` | Formats the MoonBit code |
| `mise run openspec:validate` | Validates the schema and every change and spec in strict mode |
| `mise run openspec:setup` | Regenerates the OpenSpec agent skills |
| `mise run build:site`, `check:site`, `dev:site` | Builds, checks and serves the docs site |
| `mise run release:package` | Packages `moonrockz/extism`, audits the archive and records its SHA-256 |
| `mise run release:policy` | Checks that `pkgs/extism` is the only public module |
| `mise run check:wamr` | Compares each vendored WAMR and SIMDe file with its SHA-256 in `pkgs/extism/engine/wamr/UPSTREAM.md` |

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md). Agents read [AGENTS.md](AGENTS.md).

## License

Apache-2.0. See [LICENSE](LICENSE).
