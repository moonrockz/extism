///|
/// Builds, checks or serves the docs site of this repository with `moonrockz/telescope/host`. The
/// configuration is `site/site.json` and the output is `_site/`. Run it from the repository root, or
/// through `mise run build:site`, `check:site` and `dev:site`.
///
/// With `--json`, `build` and `check` write one report to stdout and nothing else; the human
/// diagnostics go to stderr. The exit status is 0 for success, 1 for a build or check failure and 2
/// for a usage error.
async fn main {
  let invocation = Invocation::parse(@env.args()[1:]) catch {
    error => {
      eprintln("site: \{error}\n\{usage}")
      @sys.exit(2)
      return
    }
  }
  let command = invocation.command
  let report = run(command) catch {
    @model.Invalid(problems) =>
      Report::failed(command, diagnostics=json_diagnostics(problems))
    error => {
      eprintln("site \{command.name()}: \{config_path}: \{error}")
      Report::failed(command, diagnostics=[
        { "source": config_path, "line": 0, "message": "\{error}" },
      ])
    }
  }
  if invocation.json {
    println(report.to_json().stringify())
  }
  @sys.exit(report.exit_code())
}

///|
/// Runs a command and gives its report. `serve` returns only when a signal stops the server.
async fn run(command : Command) -> Report {
  match command {
    Build => {
      let warnings = @host.build(".", config_path, out_dir)
      if !warnings.is_empty() {
        eprintln(@host.diagnostics(warnings, "text"))
      }
      eprintln("Built \{out_dir}")
      Report::succeeded(command, diagnostics=json_diagnostics(warnings))
    }
    Check => {
      let config = @host.configuration(config_path)
      let problems = @host.check(out_dir, config.base_path)
      if !problems.is_empty() {
        eprintln(@host.diagnostics(problems, "text"))
        return Report::failed(command, diagnostics=json_diagnostics(problems))
      }
      eprintln("Checked \{out_dir}")
      Report::succeeded(command, diagnostics=[])
    }
    Serve(port) => {
      let config = @host.configuration(config_path)
      @host.serve(out_dir, config.base_path, port.value())
      Report::succeeded(command, diagnostics=[])
    }
  }
}

///|
/// The problems as JSON diagnostics with `source`, `line` and `message`.
fn json_diagnostics(problems : Array[@model.Problem]) -> Json {
  @json.parse(@host.diagnostics(problems, "json")) catch {
    _ => Json::array([])
  }
}
