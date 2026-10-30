name = "moonrockz/extism-qualify"

// Tooling must never publish. The pinned toolchain rejects private publication.

private = true

version = "0.1.0"

import {
  "moonbitlang/async@0.22.5",
  "moonbitlang/x@0.5.6",
  "moonrockz/extism@0.1.0",
}

description = "The EXT-2 engine qualification gate of moonrockz/extism; excluded from publication"

repository = "https://github.com/moonrockz/extism"

license = "Apache-2.0"

readme = "README.md"

preferred_target = "native"
