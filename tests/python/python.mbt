///|
/// A pinned release of the Morphir Python extension: its version, the SHA-256 of its WASM module,
/// and the SHA-256 of its `morphir_extension_info` and `describe` responses on every engine.
pub(all) struct Release {
  version : String
  module_sha256 : String
  info_sha256 : String
  describe_sha256 : String
}

///|
pub let releases : Array[Release] = [
  {
    version: "0.4.1",
    module_sha256: "a04722e16115667fc7c332177805dcb049aef563afcee0e5f80c5fea302f5b4e",
    info_sha256: "f836059bf503c963f2e20f3fd52706dca0c8c64b70ab038144b48b116c708246",
    describe_sha256: "6b6afe0581edb341c5a658334f0526f6ec8ad9c7fddedafeb1418b3936859953",
  },
  {
    version: "0.4.2",
    module_sha256: "10acafa0f0282c5240e9620a5f2bb21629cc7580b9add528e7b77c7e54db22b5",
    info_sha256: "2365b481e3b68f8733da142e420d47e430e5ae221e5ebbe201c8c99098629afa",
    describe_sha256: "41536aa556dbae9401794c7262506438d3bb95e286f054bd8373bae5195f47d3",
  },
]

///|
/// The MEP `describe` request that the Morphir host sends first.
pub let describe_request : String = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"morphir.extension.describe\",\"params\":{\"protocolVersions\":[\"0.1\"]}}"

///|
pub fn sha256(bytes : Bytes) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(bytes))
}

///|
/// The responses of the plugin `module_` to `morphir_extension_info` and to the `describe` request
/// through `handle`, with the default manifest.
pub fn responses(module_ : Bytes) -> (Bytes, Bytes) raise {
  let plugin = @extism.Plugin::load(@extism.Manifest::new(module_))
  let info = plugin.call(
    @extism.ExportName::parse("morphir_extension_info"),
    b"",
  )
  let describe = plugin.call(
    @extism.ExportName::parse("handle"),
    @utf8.encode(describe_request),
  )
  (info, describe)
}

///|
/// A JSON report of one release: the digests of the module and of both responses, and whether they
/// are the pinned ones.
pub fn report(release : Release, module_ : Bytes) -> String {
  let fields = try {
    let (info, describe) = responses(module_)
    let info_sha = sha256(info)
    let describe_sha = sha256(describe)
    let same = sha256(module_) == release.module_sha256 &&
      info_sha == release.info_sha256 &&
      describe_sha == release.describe_sha256
    "\"info\":\"\{info_sha}\",\"describe\":\"\{describe_sha}\",\"same\":\{same}"
  } catch {
    error => "\"error\":\"\{error}\",\"same\":false"
  }
  "{\"version\":\"\{release.version}\",\{fields}}"
}
