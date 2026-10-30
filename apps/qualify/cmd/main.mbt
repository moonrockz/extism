///|
/// The EXT-2 qualification gate (design GATE-1).
///
/// It loads an Extism plugin on the native engine with the embedded kernel: each `extism:host/env`
/// kernel import is linked to the kernel instance (the raw-native forwarders of BND-1), each
/// `wasi_snapshot_preview1` import answers `ENOTCAPABLE`, and each `extism:host/user` `morphir_*` import
/// is a stub that gives zeros. It sends `morphir.initialize` and then the compile request of the fixture
/// through `handle`, with an instruction budget, and finds the instructions of one compile by bisection
/// of the budget on fresh instances.
///
/// Usage: `qualify --plugin <file> --fixture <dir> [--budget <n>] [--repeat <n>] [--platform <text>]
/// [--plugin-sha256 <hex>] [--wamr-commit <hex>] [--json]`. Run it from `mise run qualify:engine`.
///
/// With `--json` it writes one report to stdout; diagnostics go to stderr. The exit status is 0 when
/// the gate passes, 1 when it fails and 2 for a usage error.

///|
/// The gate: one compile within 30 seconds.
let gate_milliseconds : Double = 30000.0

///|
suberror UsageError {
  UsageError(String)
}

///|
suberror GateError {
  GateError(String)
}

///|
struct Options {
  plugin : String
  fixture : String
  budget : Int64
  repeat : Int32
  platform : String
  plugin_sha256 : String
  wamr_commit : String
  json : Bool
}

///|
fn Options::parse(args : ArrayView[String]) -> Options raise UsageError {
  let values : Map[String, String] = Map([])
  let mut json = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "--json" {
      json = true
      i += 1
    } else if arg.has_prefix("--") && i + 1 < args.length() {
      values[arg[2:].to_owned()] = args[i + 1]
      i += 2
    } else {
      raise UsageError("unexpected argument \{arg}")
    }
  }
  guard values.get("plugin") is Some(plugin) else {
    raise UsageError("--plugin is required")
  }
  guard values.get("fixture") is Some(fixture) else {
    raise UsageError("--fixture is required")
  }
  let number = (key : String, default : Int64) => {
    match values.get(key) {
      Some(text) =>
        @string.parse_int64(text) catch {
          _ => raise UsageError("--\{key} must be a number")
        }
      None => default
    }
  }
  {
    plugin,
    fixture,
    budget: number("budget", 1000000000L),
    repeat: number("repeat", 20L).to_int(),
    platform: values.get("platform").unwrap_or("unknown"),
    plugin_sha256: values.get("plugin-sha256").unwrap_or("unknown"),
    wamr_commit: values.get("wamr-commit").unwrap_or("unknown"),
    json,
  }
}

///|
/// The answer of WASI functions in the stub sandbox: `ENOTCAPABLE`.
let enotcapable : Int32 = 76

///|
/// A plugin instance with its own kernel instance.
struct Session {
  kernel : @engine.Instance
  plugin : @engine.Instance
}

///|
fn Session::start(
  kernel : @engine.Module,
  plugin : @engine.Module,
) -> Session raise {
  let kernel_instance = kernel.instantiate(@engine.Imports::new())
  let imports = @engine.Imports::new()
  for import_ in plugin.imports() {
    guard import_.kind is Function(Some(signature)) else {
      raise GateError(
        "\{import_.module_}.\{import_.name} is not a number-typed function",
      )
    }
    if import_.module_ == @kernel.import_namespace {
      guard kernel_instance.export_function(import_.name) is Some(function) else {
        raise GateError("the kernel has no function \{import_.name}")
      }
      imports.function(import_.module_, import_.name, function) |> ignore
    } else if import_.module_ == "wasi_snapshot_preview1" {
      imports.host(import_.module_, import_.name, signature, (_, _) => {
        signature.results.map(_ => @engine.Value::I32(enotcapable))
      })
      |> ignore
    } else if import_.module_ == "extism:host/user" &&
      import_.name.has_prefix("morphir_") {
      imports.host(import_.module_, import_.name, signature, (_, _) => {
        signature.results.map(t => {
          match t {
            I32 => @engine.Value::I32(0)
            I64 => I64(0)
            F32 => F32(0)
            F64 => F64(0)
          }
        })
      })
      |> ignore
    } else {
      raise GateError("the gate links no \{import_.module_}.\{import_.name}")
    }
  }
  { kernel: kernel_instance, plugin: plugin.instantiate(imports), }
}

///|
fn Session::kernel_call(
  self : Session,
  name : String,
  args : Array[@engine.Value],
) -> Int64 raise {
  match self.kernel.call(name, args) {
    [I64(value)] => value
    [I32(value)] => value.to_int64()
    _ => 0L
  }
}

///|
/// Calls the export `name` with `input` as an Extism call; gives the output, or raises.
fn Session::call(
  self : Session,
  name : String,
  input : Bytes,
  budget? : @engine.Budget,
) -> Bytes raise {
  guard self.kernel.memory() is Some(memory) else {
    raise GateError("the kernel has no memory")
  }
  self.kernel_call("reset", []) |> ignore
  if input.length() > 0 {
    let handle = self.kernel_call("alloc", [I64(input.length().to_int64())])
    memory.write(handle, input)
    self.kernel_call("input_set", [I64(handle), I64(input.length().to_int64())])
    |> ignore
  }
  let rc = self.plugin.call(name, [], budget?)
  let error = self.kernel_call("error_get", [])
  if error != 0L {
    let length = self.kernel_call("length", [I64(error)])
    if length != 0L {
      raise GateError(@utf8.decode_lossy(memory.read(error, length.to_int())))
    }
  }
  guard rc is [I32(0)] else {
    raise GateError("\{name} returned another result than i32 0")
  }
  let offset = self.kernel_call("output_offset", [])
  let length = self.kernel_call("output_length", [])
  memory.read(offset, length.to_int())
}

///|
fn request(id : Int32, name : String, params : Json) -> Bytes {
  @utf8.encode(
    (
      {
        "jsonrpc": "2.0",
        "id": id.to_double(),
        "method": name,
        "params": params,
      } : Json).stringify(),
  )
}

///|
async fn compile_request(fixture : String) -> Bytes {
  let document = async fn(path : String) -> Json {
    {
      "uri": "file:///fixture/\{path}",
      "languageId": "python",
      "version": 1,
      "text": @fs.read_file("\{fixture}/\{path}").text(),
    }
  }
  request(2, "morphir.frontend.compile", {
    "languageId": "python",
    "sources": {
      "root": "file:///fixture",
      "documents": [document("acme/models.py"), document("acme/rules.py")],
    },
    "package": { "name": "acme/loans", "exposedModules": ["acme.rules"] },
    "options": { "typesOnly": false, "irVersion": "4.0.0" },
  })
}

///|
let initialize : Bytes = request(1, "morphir.initialize", {
  "protocolVersions": ["0.1"],
  "host": { "name": "moonrockz-extism-qualify", "version": "0.1.0" },
})

///|
fn succeeded(output : Bytes) -> Bool {
  let reply = @json.parse(@utf8.decode_lossy(output)) catch {
    _ => return false
  }
  reply is { "result": { "success": true, .. }, .. }
}

///|
/// The smallest budget with which one compile on a fresh instance succeeds.
fn instructions(
  kernel : @engine.Module,
  plugin : @engine.Module,
  compile : Bytes,
  limit : Int64,
) -> Int64 raise {
  let passes = (budget : Int64) => {
    let session = Session::start(kernel, plugin)
    session.call("handle", initialize) |> ignore
    let output = session.call(
      "handle",
      compile,
      budget=@engine.Budget::parse(budget),
    ) catch {
      _ => return false
    }
    succeeded(output)
  }
  guard passes(limit) else {
    raise GateError("the compile does not finish within the budget")
  }
  let mut low = 1L
  let mut high = limit
  while low < high {
    let middle = low + (high - low) / 2L
    if passes(middle) {
      high = middle
    } else {
      low = middle + 1L
    }
  }
  low
}

///|
fn elapsed(start : UInt64) -> Double {
  (@env.now() - start).to_double()
}

///|
async fn qualify(options : Options) -> Json {
  let engine = @engine.Engine::default()
  let bytes = @fs.read_file(options.plugin).binary()
  let compile = compile_request(options.fixture)
  let budget = @engine.Budget::parse(options.budget)
  let started = @env.now()
  let plugin = engine.compile(bytes)
  let kernel = engine.compile(@kernel.bytes())
  let load_ms = elapsed(started)
  let instantiated = @env.now()
  let session = Session::start(kernel, plugin)
  let instantiate_ms = elapsed(instantiated)
  let info = session.call("morphir_extension_info", b"", budget~)
  session.call("handle", initialize, budget~) |> ignore
  let first = @env.now()
  let output = session.call("handle", compile, budget~)
  let first_ms = elapsed(first)
  guard succeeded(output) else {
    raise GateError("the compile failed: \{@utf8.decode_lossy(output)}")
  }
  let repeated = @env.now()
  for _ in 0..<options.repeat {
    guard succeeded(session.call("handle", compile, budget~)) else {
      raise GateError("a repeated compile failed")
    }
  }
  let mean_ms = elapsed(repeated) / @cmp.maximum(options.repeat, 1).to_double()
  let used = instructions(kernel, plugin, compile, options.budget)
  let bounds = engine.bounds()
  {
    "gate": "EXT-2",
    "passed": first_ms < gate_milliseconds && mean_ms < gate_milliseconds,
    "platform": options.platform,
    "engine": "WAMR fast interpreter",
    "wamrCommit": options.wamr_commit,
    "kernelBinding": "raw-native forwarders",
    "kernelSha256": @kernel.sha256(),
    "pluginSha256": options.plugin_sha256,
    "pluginBytes": bytes.length().to_double(),
    "extension": @json.parse(@utf8.decode_lossy(info)),
    "budget": options.budget.to_double(),
    "instructionsPerCompile": used.to_double(),
    "loadMilliseconds": load_ms,
    "instantiateMilliseconds": instantiate_ms,
    "firstCompileMilliseconds": first_ms,
    "meanCompileMilliseconds": mean_ms,
    "repeat": options.repeat.to_double(),
    "gateMilliseconds": gate_milliseconds,
    "bounds": {
      "memory": bounds.memory is Enforced,
      "budget": bounds.budget is Enforced,
      "interruption": bounds.interruption is Enforced,
    },
  }
}

///|
async fn main {
  let options = Options::parse(@env.args()[1:]) catch {
    UsageError(message) => {
      eprintln("qualify: \{message}")
      @sys.exit(2)
      return
    }
  }
  let report : Json = try qualify(options) catch {
    error => {
      eprintln("qualify: \{error}")
      {
        "command": "qualify",
        "state": "failed",
        "exitCode": 1,
        "diagnostics": [],
        "error": { "code": "qualify.failed", "message": "\{error}" },
      }
    }
  } noraise {
    receipt => {
      let passed = receipt is { "passed": true, .. }
      {
        "command": "qualify",
        "state": if passed {
          "succeeded"
        } else {
          "failed"
        },
        "exitCode": if passed {
          0
        } else {
          1
        },
        "diagnostics": [],
        "result": receipt,
      }
    }
  }
  if options.json {
    println(report.stringify())
  } else {
    println(report.stringify(indent=2))
  }
  if !(report is { "state": "succeeded", .. }) {
    @sys.exit(1)
  }
}
