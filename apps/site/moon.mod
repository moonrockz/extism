name = "moonrockz/extism-site"

// Tooling must never publish. The pinned toolchain rejects private publication.

private = true

version = "0.3.0"

import {
  "moonbitlang/async@0.22.7",
  "moonbitlang/x@0.5.6",
  "moonrockz/telescope@0.6.0",
}

description = "Docs site driver for moonrockz/extism, over moonrockz/telescope; excluded from publication"

repository = "https://github.com/moonrockz/extism"

license = "Apache-2.0"

readme = "README.md"

preferred_target = "native"
