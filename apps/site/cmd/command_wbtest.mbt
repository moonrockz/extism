///|
test "each command name parses to its command" {
  assert_eq(Invocation::parse(["build"]), { command: Build, json: false })
  assert_eq(Invocation::parse(["check"]), { command: Check, json: false })
  assert_eq(Invocation::parse(["serve"]), {
    command: Serve(Port::default()),
    json: false,
  })
}

///|
test "--json selects JSON output for a finite command" {
  assert_eq(Invocation::parse(["build", "--json"]), {
    command: Build,
    json: true,
  })
  assert_eq(Invocation::parse(["check", "--json"]), {
    command: Check,
    json: true,
  })
}

///|
test "serve takes a port" {
  assert_eq(Invocation::parse(["serve", "--port", "8080"]), {
    command: Serve(Port::parse("8080")),
    json: false,
  })
}

///|
test "a port is an integer from 1 to 65535" {
  assert_eq(Port::parse("1").value(), 1)
  assert_eq(Port::parse("65535").value(), 65535)
  assert_eq(Port::default().value(), 4173)
  for text in ["0", "65536", "-1", "", "80a", "4173.0"] {
    let message = try {
      ignore(Port::parse(text))
      "accepted"
    } catch {
      InvalidPort(value) => "rejected \{value}"
      error => "unexpected \{error}"
    }
    assert_eq(message, "rejected \{text}")
  }
}

///|
test "usage errors name the argument" {
  let cases : Array[(Array[String], String)] = [
    ([], "a command is missing"),
    (["deploy"], "unknown command `deploy`"),
    (["build", "--port", "80"], "unknown option `--port`"),
    (["build", "--verbose"], "unknown option `--verbose`"),
    (["serve", "--port"], "`--port` needs a value"),
    (["serve", "--json"], "unknown option `--json`"),
  ]
  for case in cases {
    let (args, expected) = case
    let message = try {
      ignore(Invocation::parse(args))
      "accepted"
    } catch {
      error => "\{error}"
    }
    assert_eq(message, expected)
  }
}
