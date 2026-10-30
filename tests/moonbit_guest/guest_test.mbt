///|
/// The path of the portable MoonBit guest's `model.wasm`, from `mise run test:moonbit-guest`; the test
/// needs it.
fn guest_path() -> String? {
  @env.get_env_var("EXTISM_MOONBIT_GUEST")
}

///|
test "MoonBit guest with SIMD: model.wasm answers describe and exits" {
  guard guest_path() is Some(path) else {
    println("EXTISM_MOONBIT_GUEST is not set; run mise run test:moonbit-guest")
    return
  }
  let guest = @moonbit_guest.Guest::load(@fs.read_file_to_bytes(path))
  let describe = guest.exchange(@moonbit_guest.describe_request)
  assert_eq(describe.code, describe.output.length())
  assert_true(describe.code > 0)
  let response = @json.parse(@utf8.decode(describe.output))
  guard response
    is {
      "jsonrpc": String("2.0"),
      "id": Number(1, ..),
      "result": {
        "claimsVersion": String("0.1.0-draft.2"),
        "protocolVersions": Array(versions),
        "extension": { "id": String("morphir-moonbit"), .. },
        "capabilities": Object(_),
        ..
      },
      ..
    } else {
    fail("the describe response lacks a field: \{response.stringify()}")
  }
  assert_false(response is { "error": _, .. })
  assert_true(versions.contains(Json::string("0.2.0-draft.1")))
  assert_true(versions.contains(Json::string("0.1")))
  assert_eq(guest.exchange(@moonbit_guest.exit_request).code, 0)
}
