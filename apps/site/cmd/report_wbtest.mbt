///|
test "a successful JSON report has a result and no error" {
  let report = Report::succeeded(Build, diagnostics=[])
  assert_eq(report.exit_code(), 0)
  json_inspect(report.to_json(), content={
    "command": "build",
    "state": "succeeded",
    "exitCode": 0,
    "diagnostics": [],
    "result": { "out": "_site" },
  })
}

///|
test "a failed JSON report has an error and keeps the diagnostics" {
  let diagnostics : Json = [
    { "source": "docs/a.md", "line": 3, "message": "missing page" },
  ]
  let report = Report::failed(Check, diagnostics~)
  assert_eq(report.exit_code(), 1)
  json_inspect(report.to_json(), content={
    "command": "check",
    "state": "failed",
    "exitCode": 1,
    "diagnostics": [
      { "source": "docs/a.md", "line": 3, "message": "missing page" },
    ],
    "error": { "code": "site.check_failed", "message": "check found 1 problem" },
  })
}
