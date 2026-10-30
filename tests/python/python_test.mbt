///|
/// The directory of the pinned modules, from `mise run test:python`; the test needs it.
fn modules_dir() -> String? {
  @env.get_env_var("EXTISM_PYTHON_DIR")
}

///|
test "Python extension describe: 0.4.1 and 0.4.2 give the pinned responses" {
  guard modules_dir() is Some(dir) else {
    println("EXTISM_PYTHON_DIR is not set; run mise run test:python")
    return
  }
  for release in @python.releases {
    let path = "\{dir}/morphir-python-binding-\{release.version}.wasm"
    let module_ = @fs.read_file_to_bytes(path)
    assert_eq(@python.sha256(module_), release.module_sha256)
    let (info, describe) = @python.responses(module_)
    assert_eq(
      @python.sha256(info),
      release.info_sha256,
      msg="info of \{release.version}",
    )
    assert_eq(
      @python.sha256(describe),
      release.describe_sha256,
      msg="describe of \{release.version}",
    )
  }
}
