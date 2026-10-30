///|
/// The MEP `describe` request that the Morphir host sends to the portable MoonBit guest first.
pub let describe_request : String = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"morphir.extension.describe\",\"params\":{\"protocolVersions\":[\"0.2.0-draft.1\"]}}"

///|
/// The MEP request that ends the guest.
pub let exit_request : String = "{\"jsonrpc\":\"2.0\",\"method\":\"morphir.exit\"}"

///|
/// One exchange of the `morphir/byte-adapter/v1-draft` ABI: the code that `handle` returns, and the
/// bytes that the guest gave through `output_byte`.
pub(all) struct Exchange {
  code : Int
  output : Bytes
}

///|
/// A guest of the byte-adapter ABI on the engine: its instance, and the request and the response of
/// the exchange that runs.
pub struct Guest {
  priv instance : @engine.Instance
  priv input : Ref[Bytes]
  priv output : Array[Byte]
}

///|
/// Compiles `module_` and links the three `morphir_bytes_v1` imports to the exchange buffers.
pub fn Guest::load(module_ : Bytes) -> Guest raise @engine.EngineError {
  let input : Ref[Bytes] = Ref(b"")
  let output : Array[Byte] = []
  let imports = @engine.Imports::new()
    .host(
      "morphir_bytes_v1",
      "input_len",
      @engine.Signature::new([], [I32]),
      (_, _) => [I32(input.val.length())],
    )
    .host(
      "morphir_bytes_v1",
      "input_byte",
      @engine.Signature::new([I32], [I32]),
      (_, args) => {
        guard args is [I32(index)] && index >= 0 && index < input.val.length() else {
          raise @engine.HostError("input index outside the request")
        }
        [I32(input.val[index].to_int())]
      },
    )
    .host(
      "morphir_bytes_v1",
      "output_byte",
      @engine.Signature::new([I32], []),
      (_, args) => {
        guard args is [I32(byte)] && byte >= 0 && byte <= 255 else {
          raise @engine.HostError("output byte outside 0..255")
        }
        output.push(byte.to_byte())
        []
      },
    )
  let instance = @engine.Engine::default().compile(module_).instantiate(imports)
  { instance, input, output }
}

///|
/// Sends `request` to the guest and gives the code of `handle` and the response bytes.
pub fn Guest::exchange(
  self : Guest,
  request : String,
) -> Exchange raise @engine.CallError {
  self.input.val = @utf8.encode(request)
  self.output.clear()
  let code = match self.instance.call("handle", []) {
    [I32(code)] => code
    _ => -1
  }
  { code, output: Bytes::from_array(self.output) }
}
