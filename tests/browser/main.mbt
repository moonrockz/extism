///|
extern "js" fn install(check : (String, Bytes) -> String) = "(check) => { globalThis.extismPythonCheck = check; }"

///|
/// Installs `globalThis.extismPythonCheck(version, bytes)`, which gives the JSON report of one
/// release of the Python extension in the browser.
fn main {
  install((version, bytes) => {
    match @python.releases.iter().find_first(r => r.version == version) {
      Some(release) => @python.report(release, bytes)
      None =>
        "{\"version\":\"\{version}\",\"error\":\"not a pinned release\",\"same\":false}"
    }
  })
}
