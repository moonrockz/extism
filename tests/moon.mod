name = "moonrockz/extism-tests"

// Tests and fixtures with third-party bytes. Tooling must never publish. The pinned toolchain rejects
// private publication.

private = true

version = "0.1.0"

import {
  "moonbitlang/x@0.5.6",
  "moonrockz/extism@0.1.0",
}

description = "Tests of moonrockz/extism with upstream fixtures; excluded from publication"

repository = "https://github.com/moonrockz/extism"

license = "Apache-2.0"

readme = "README.md"

preferred_target = "native"
