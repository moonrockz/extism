///|
/// A TCP port for the local preview server, from 1 to 65535.
struct Port(Int) derive(Eq, Debug)

///|
/// The port that `serve` uses without `--port`.
fn Port::default() -> Port {
  Port(4173)
}

///|
/// Parses a decimal port number. Text that is not a number from 1 to 65535 raises `InvalidPort`.
fn Port::parse(text : String) -> Port raise UsageError {
  let number = @string.parse_int(text) catch { _ => raise InvalidPort(text) }
  guard number >= 1 && number <= 65535 else { raise InvalidPort(text) }
  Port(number)
}

///|
fn Port::value(self : Port) -> Int {
  self.0
}

///|
/// A site command. `build` and `check` are finite; `serve` runs until it receives SIGINT or SIGTERM.
enum Command {
  Build
  Check
  Serve(Port)
} derive(Eq, Debug)

///|
/// The command name, as the user types it and as JSON reports give it.
fn Command::name(self : Command) -> String {
  match self {
    Build => "build"
    Check => "check"
    Serve(_) => "serve"
  }
}

///|
/// A parsed command line.
struct Invocation {
  command : Command
  /// Write one JSON report to stdout, and human diagnostics to stderr.
  json : Bool
} derive(Eq, Debug)

///|
/// A command line that the site driver does not accept. The payload is the argument at fault.
suberror UsageError {
  MissingCommand
  UnknownCommand(String)
  UnknownOption(String)
  MissingValue(String)
  InvalidPort(String)
}

///|
impl Show for UsageError with output(self, logger) {
  logger.write_string(
    match self {
      MissingCommand => "a command is missing"
      UnknownCommand(name) => "unknown command `\{name}`"
      UnknownOption(option) => "unknown option `\{option}`"
      MissingValue(option) => "`\{option}` needs a value"
      InvalidPort(text) => "`\{text}` is not a port from 1 to 65535"
    },
  )
}

///|
let usage : String = "Usage: site build [--json] | check [--json] | serve [--port <1-65535>]"

///|
/// Parses the arguments after the program name. `build` and `check` accept `--json`; `serve`
/// accepts `--port`, because it gives no finite result.
fn Invocation::parse(args : ArrayView[String]) -> Invocation raise UsageError {
  guard args is [name, .. options] else { raise MissingCommand }
  match name {
    "build" | "check" => {
      let mut json = false
      for option in options {
        guard option == "--json" else { raise UnknownOption(option) }
        json = true
      }
      { command: if name == "build" { Build } else { Check }, json }
    }
    "serve" => {
      let mut port = Port::default()
      let mut rest = options
      while rest is [option, .. tail] {
        guard option == "--port" else { raise UnknownOption(option) }
        guard tail is [value, .. after] else { raise MissingValue(option) }
        port = Port::parse(value)
        rest = after
      }
      { command: Serve(port), json: false }
    }
    _ => raise UnknownCommand(name)
  }
}
