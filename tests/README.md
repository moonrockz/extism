# moonrockz/extism-tests

Tests of `moonrockz/extism` that use third-party fixtures, so that the published module has no third-party
bytes. It is not published.

- `upstream/`: the upstream Extism kernel `extism-runtime.wasm` (extism/extism `v1.41.0`, commit
  `051b765bb6abe4fe95d5e4f489f03ad7b137edbc`, SHA-256
  `d1389b31abecf23eec65b4430d86f99f736aeb05c40948dbbe2f88cb17815803`, `LICENSE-extism`, BSD-3-Clause) for the
  differential kernel test (KRN-2), and the count-vowels plugin of extism/wamr-sdk (commit
  `fb0a73532462feaf61d2bdcdf52ba82ed4d0ece2`, `wasm/count-vowels.wasm`, SHA-256
  `4958d0e8a21a3f2c17605744ba5fc7e830e64d4b880489899c2a9333c72849ad`, `LICENSE-wamr-sdk`, BSD-3-Clause).
  The test checks the SHA-256 of each fixture.
- `python/`: the Morphir Python extension `0.4.1` and `0.4.2` answer `morphir_extension_info` and a
  `describe` request through `handle`. `mise run test:python` fetches the pinned modules first.
