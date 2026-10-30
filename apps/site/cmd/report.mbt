///|
/// The JSON result of a finite site command. Success has a `result`; failure has an `error` in its place.
struct Report {
  command : Command
  diagnostics : Json
  failed : Bool
}

///|
/// The output directory of the site, relative to the repository root.
let out_dir : String = "_site"

///|
/// The configuration file of the site, relative to the repository root.
let config_path : String = "site/site.json"

///|
fn Report::succeeded(command : Command, diagnostics~ : Json) -> Report {
  { command, diagnostics, failed: false }
}

///|
fn Report::failed(command : Command, diagnostics~ : Json) -> Report {
  { command, diagnostics, failed: true }
}

///|
/// 0 for success and 1 for a build or check failure. A usage error exits with 2 before a report exists.
fn Report::exit_code(self : Report) -> Int {
  if self.failed {
    1
  } else {
    0
  }
}

///|
fn Report::to_json(self : Report) -> Json {
  let fields : Map[String, Json] = {
    "command": Json(self.command.name()),
    "state": Json(if self.failed { "failed" } else { "succeeded" }),
    "exitCode": Json(self.exit_code()),
    "diagnostics": self.diagnostics,
  }
  if self.failed {
    let count = match self.diagnostics {
      Array(items) => items.length()
      _ => 0
    }
    let noun = if count == 1 { "problem" } else { "problems" }
    fields["error"] = {
      "code": "site.\{self.command.name()}_failed",
      "message": "\{self.command.name()} found \{count} \{noun}",
    }
  } else {
    fields["result"] = { "out": out_dir }
  }
  Json::object(fields)
}
