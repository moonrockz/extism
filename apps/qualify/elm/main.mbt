///|
/// Temporary measurement for bead morphir-ukvn.5.64.36.20: times the calls of a `morphir-bytes-v1`
/// guest on the native engine, with the instruction budget of the EXT-2 gate and a deadline of 60000 ms,
/// so that a call over the 10000 ms deadline of the morphir-moonbit worker is still timed. The requests in `requests/` are the ones that the morphir-moonbit CLI sends for the compile of
/// its Elm fixture: initialize, initialized and the compile.
///
/// Usage: `elm <url> <sha256> <new work dir> <requests dir> <rounds>`. It downloads the module with
/// curl into the new, empty work dir, checks its SHA-256, and writes one JSON line to stdout.

///|
suberror ReplayError {
  ReplayError(String)
}

///|
struct Guest {
  instance : @engine.Instance
  input : Ref[Bytes]
  output : Array[Byte]
}

///|
fn Guest::start(module_ : @engine.Module) -> Guest raise {
  let input : Ref[Bytes] = { val: b"", }
  let output : Array[Byte] = []
  let ns = "morphir_bytes_v1"
  let imports = @engine.Imports::new()
    .host(ns, "input_len", @engine.Signature::new([], [I32]), (_, _) => {
      [I32(input.val.length())]
    })
    .host(ns, "input_byte", @engine.Signature::new([I32], [I32]), (_, args) => {
      guard args is [I32(index)] && index >= 0 && index < input.val.length() else {
        raise HostError("input_byte out of range")
      }
      [I32(input.val[index].to_int())]
    })
    .host(ns, "output_byte", @engine.Signature::new([I32], []), (_, args) => {
      guard args is [I32(value)] else { raise HostError("output_byte") }
      output.push(value.to_byte())
      []
    })
  let instance = module_.instantiate(
    imports,
    memory_ceiling=@engine.PageCount::default_ceiling(),
  )
  { instance, input, output, }
}

///|
fn Guest::handle(
  self : Guest,
  request : Bytes,
  budget : @engine.Budget,
  deadline : @engine.Deadline,
) -> (Int32, Double) raise {
  self.input.val = request
  self.output.clear()
  let start = @env.now()
  let results = self.instance.call("handle", [], budget~, deadline~)
  let ms = (@env.now() - start).to_double()
  guard results is [I32(result)] && result != -1 else {
    raise ReplayError("handle failed: \{@debug.to_string(results)}")
  }
  (result, ms)
}

///|
async fn replay(args : ArrayView[String]) -> Json {
  guard args is [url, sha256, work, dir, rounds] else {
    raise ReplayError(
      "usage: elm <url> <sha256> <new work dir> <requests dir> <rounds>",
    )
  }
  @fs.mkdir(work)
  let wasm = "\{work}/guest.wasm"
  let code = @process.run(
    "curl",
    ["-fsSL", "-o", wasm, url],
    stdout=@stdio.stderr,
    stderr=@stdio.stderr,
  )
  guard code == 0 else { raise ReplayError("curl could not fetch \{url}") }
  let bytes = @fs.read_file(wasm).binary()
  let digest = @crypto.bytes_to_hex_string(@crypto.sha256(bytes))
  guard digest == sha256 else {
    raise ReplayError("\{wasm} has SHA-256 \{digest}, not \{sha256}")
  }
  let rounds = @string.parse_int(rounds)
  let requests = [
    @fs.read_file("\{dir}/req-1.json").binary(),
    @fs.read_file("\{dir}/req-2.json").binary(),
    @fs.read_file("\{dir}/req-3.json").binary(),
  ]
  let budget = @engine.Budget::parse(1000000000L)
  let deadline = @engine.Deadline::parse(60000)
  let engine = @engine.Engine::default()
  let loaded = @env.now()
  let module_ = engine.compile(bytes)
  let load_ms = (@env.now() - loaded).to_double()
  let compiles : Array[Json] = []
  let mut instantiate_ms = 0.0
  let mut initialize_ms = 0.0
  for round in 0..<rounds {
    let started = @env.now()
    let guest = Guest::start(module_)
    if round == 0 {
      instantiate_ms = (@env.now() - started).to_double()
    }
    let (_, init_ms) = guest.handle(requests[0], budget, deadline)
    if round == 0 {
      initialize_ms = init_ms
    }
    guest.handle(requests[1], budget, deadline) |> ignore
    let (length, ms) = guest.handle(requests[2], budget, deadline)
    guard length > 0 else { raise ReplayError("the compile gave \{length}") }
    compiles.push(Json::number(ms))
  }
  {
    "sha256": digest,
    "loadMilliseconds": load_ms,
    "instantiateMilliseconds": instantiate_ms,
    "initializeMilliseconds": initialize_ms,
    "compileMilliseconds": Json::array(compiles),
  }
}

///|
async fn main {
  let report = replay(@env.args()[1:]) catch {
    error => {
      eprintln("elm: \{error}")
      @sys.exit(1)
      return
    }
  }
  println(report.stringify())
}
