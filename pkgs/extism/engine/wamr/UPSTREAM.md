# Vendored WAMR and SIMDe

The C source of the WebAssembly Micro Runtime (WAMR) that the native engine builds, from
https://github.com/bytecodealliance/wasm-micro-runtime. License: Apache-2.0 WITH LLVM-exception
(`LICENSE`); WAMR's notes on the work that it reuses are in `ATTRIBUTIONS.md`. The SIMD
instructions of the fast interpreter use the SIMDe headers in `simde/`, from
https://github.com/simd-everywhere/simde. License: MIT (`simde/COPYING`).

Do not edit the files under `core/`, `simde/` or `unit/`: `scripts/vendor-wamr.mbtx` writes
them. It copies the WAMR files with their layout and rewrites each quoted `#include` that WAMR
resolves through an include directory of its CMake build into a path relative to the
including file, so that the engine builds with no include path. `extism_config.h` holds the
build settings. `mise run check:wamr` compares each file with its SHA-256 below.
- WAMR tag: `WAMR-2.4.5`
- WAMR commit: `25bd7eb63e828e4bd242cc9b38d260b4b31c6605`
- SIMDe tag: `v0.8.2`
- SIMDe commit: `71fd833d9666141edcd1d3c109a80e228303d8d7`

## Patches

- `core/iwasm/interpreter/wasm_interp_fast.c`: The switch dispatch of the fast interpreter, which compilers with no computed goto use (MSVC), does not meter instructions; the patch runs CHECK_INSTRUCTION_LIMIT for each instruction, as the computed-goto dispatch does. Upstream fixed it after WAMR-2.4.5 in commit ea5dd88e9ca40a44b6a5d9ffeb87a20833b13b8a (pull request #5141, issue #5140); remove this patch at the next WAMR upgrade.
- `core/iwasm/interpreter/wasm_interp_fast.c`: The SIMD code of the fast interpreter converts a V128 to a SIMDe value with a GNU statement expression, which MSVC does not compile; the patch uses a static inline function. Upstream WAMR builds SIMDe on no Windows platform (build-scripts/runtime_lib.cmake), at WAMR-2.4.5 and at main f8ed1f442969c806ced7b127d4e4d397bf051737 (2026-10-28) alike.
- `core/iwasm/interpreter/wasm_runtime.c`: The instantiation runs the guest's `__post_instantiate` and `__wasm_call_ctors` exports, with no instruction budget and no deadline, and the Extism plugin runs its start-up exports again; no WAMR setting or API skips them. The patch keeps only the wasm start function, so that the plugin's own start-up (`_initialize` and `hs_init`, else `__wasm_call_ctors`, as upstream Extism) is the only one and runs under the plugin's bounds.

## Translation units

- `wamr/unit/wamr_wasm_application.c`
- `wamr/unit/wamr_wasm_blocking_op.c`
- `wamr/unit/wamr_wasm_exec_env.c`
- `wamr/unit/wamr_wasm_loader_common.c`
- `wamr/unit/wamr_wasm_memory.c`
- `wamr/unit/wamr_wasm_native.c`
- `wamr/unit/wamr_wasm_runtime_common.c`
- `wamr/unit/wamr_wasm_interp_fast.c`
- `wamr/unit/wamr_wasm_loader.c`
- `wamr/unit/wamr_wasm_runtime.c`
- `wamr/unit/wamr_thread_manager.c`
- `wamr/unit/wamr_mem_alloc.c`
- `wamr/unit/wamr_ems_alloc.c`
- `wamr/unit/wamr_ems_gc.c`
- `wamr/unit/wamr_ems_hmu.c`
- `wamr/unit/wamr_ems_kfc.c`
- `wamr/unit/wamr_bh_assert.c`
- `wamr/unit/wamr_bh_bitmap.c`
- `wamr/unit/wamr_bh_common.c`
- `wamr/unit/wamr_bh_hashmap.c`
- `wamr/unit/wamr_bh_leb128.c`
- `wamr/unit/wamr_bh_list.c`
- `wamr/unit/wamr_bh_log.c`
- `wamr/unit/wamr_bh_queue.c`
- `wamr/unit/wamr_bh_vector.c`
- `wamr/unit/wamr_runtime_timer.c`
- `wamr/unit/wamr_posix_blocking_op.c`
- `wamr/unit/wamr_posix_malloc.c`
- `wamr/unit/wamr_posix_memmap.c`
- `wamr/unit/wamr_posix_sleep.c`
- `wamr/unit/wamr_posix_thread.c`
- `wamr/unit/wamr_posix_time.c`
- `wamr/unit/wamr_mremap.c`
- `wamr/unit/wamr_platform_init_darwin.c`
- `wamr/unit/wamr_platform_init_linux.c`
- `wamr/unit/wamr_platform_init_windows.c`
- `wamr/unit/wamr_win_malloc.c`
- `wamr/unit/wamr_win_memmap.c`
- `wamr/unit/wamr_win_thread.c`
- `wamr/unit/wamr_win_time.c`
- `wamr/unit/wamr_win_util.c`

## Files

The SHA-256 of each upstream file, and of the vendored file after the include rewrite and the patches.

| File | Upstream SHA-256 | Vendored SHA-256 |
| --- | --- | --- |
| `LICENSE` | `0a274df3755e61b169266fba62d842489378bc9a6e9a63fe24f02ee6f5de419f` | `0a274df3755e61b169266fba62d842489378bc9a6e9a63fe24f02ee6f5de419f` |
| `core/config.h` | `589dabe8ca01f472b744576593d7371b37c174524b2eb307e26c0296002dcc06` | `589dabe8ca01f472b744576593d7371b37c174524b2eb307e26c0296002dcc06` |
| `simde/COPYING` | `75ce0a8c5a7bff42fbd6f8f3b469b518132132c4f4948fb8d02b1ccb5d0df9d8` | `75ce0a8c5a7bff42fbd6f8f3b469b518132132c4f4948fb8d02b1ccb5d0df9d8` |
| `simde/check.h` | `5fb278f5294101ce081f32ed0a931f994bf7dbd83ed69357703a2240a93151c6` | `5fb278f5294101ce081f32ed0a931f994bf7dbd83ed69357703a2240a93151c6` |
| `core/version.h` | `01f4cf6e441e0372b5c70d685f6d803a00c4a1b2c3c72e4edf8014e91b951c65` | `01f4cf6e441e0372b5c70d685f6d803a00c4a1b2c3c72e4edf8014e91b951c65` |
| `simde/hedley.h` | `322e5afc323320b13296972ca3b31d62ae7c0bf714e75536f020d28d20d87f3d` | `322e5afc323320b13296972ca3b31d62ae7c0bf714e75536f020d28d20d87f3d` |
| `ATTRIBUTIONS.md` | `b678717b5ed13844946754407d258727019b3731f44315886bb1c857ed18649c` | `b678717b5ed13844946754407d258727019b3731f44315886bb1c857ed18649c` |
| `simde/debug-trap.h` | `ac2841ade8b99dd6d38bdebc59c1d1444f901baa1bd7b6b60f50317472d77c01` | `ac2841ade8b99dd6d38bdebc59c1d1444f901baa1bd7b6b60f50317472d77c01` |
| `simde/simde-arch.h` | `5d8a8483e0411b3f4e80dccc2aa1af08109c36fc3cf880ae2923462c84188fa1` | `5d8a8483e0411b3f4e80dccc2aa1af08109c36fc3cf880ae2923462c84188fa1` |
| `simde/simde-math.h` | `ba322ecd4c4f2b9eb38233f6e1126e3cd0dfb4a792976f2047b6f0fd8e74ccfa` | `ba322ecd4c4f2b9eb38233f6e1126e3cd0dfb4a792976f2047b6f0fd8e74ccfa` |
| `unit/wamr_bh_log.c` | (made by the script) | `27a6b1175a07edf286d8ae4a02559296486d58d95bfb1c3805e1e854b8bbf457` |
| `unit/wamr_ems_gc.c` | (made by the script) | `b529bbedecb4c4cd27646a0de7fa96e36477a6ddf72c127a854bb3a62275b08d` |
| `unit/wamr_mremap.c` | (made by the script) | `cdeadc35865d9cc864ff6a49219c23234a859e7029e60a8d6f271763171e6806` |
| `simde/simde-align.h` | `948d91b0f12f49440cb2e73c09cee27d71679a7b8be4e55f174af0d3a88fcb2d` | `948d91b0f12f49440cb2e73c09cee27d71679a7b8be4e55f174af0d3a88fcb2d` |
| `unit/wamr_bh_list.c` | (made by the script) | `abc7d3646006a5cb478c1dc6991e2b7686c64f064c34fb4eb69919d7a32ceaea` |
| `unit/wamr_ems_hmu.c` | (made by the script) | `e3ef99433262e41790b3e0f0bca0ce6398a4924458c81f1ef7aac6151daf7a55` |
| `unit/wamr_ems_kfc.c` | (made by the script) | `7bb71556535808cb9559da28dd79186c2d1fd584e688915afdd8d7a1e6a215f5` |
| `simde/simde-common.h` | `061c858a9dad573a55365cbda4239ee748d3f951b468216377aca9ecd1e55e29` | `061c858a9dad573a55365cbda4239ee748d3f951b468216377aca9ecd1e55e29` |
| `simde/wasm/simd128.h` | `7e2fed8b9884a206dcf12951c6cc78e13f0db24076cf45b61a2da293089ce70b` | `7e2fed8b9884a206dcf12951c6cc78e13f0db24076cf45b61a2da293089ce70b` |
| `unit/wamr_bh_queue.c` | (made by the script) | `6e414f91ead083a7db8e52e6a187a360c6d30e5641c5f7acfef77b7a97fbc1c6` |
| `unit/wamr_win_time.c` | (made by the script) | `06ca32dc2f55cc9bad6bd0b028e3dff22ba0f9703e3871f3e5ad9e115e2e40b8` |
| `unit/wamr_win_util.c` | (made by the script) | `ae6379246a1b4510b57bb94bdcf249f3d40dd172b819f47e008af769e0667041` |
| `unit/wamr_bh_assert.c` | (made by the script) | `9f5c011442651e98fcc92b67e7f946473685017dbf60d2ec9002cb76873c8e99` |
| `unit/wamr_bh_bitmap.c` | (made by the script) | `337c4b19489de6add49f5656a3c3f3172a08501415882de6e6552308b3314335` |
| `unit/wamr_bh_common.c` | (made by the script) | `bd5a32070a0cdbd6c847f43e6ffeb59a2d40a07b9c5dbbdb18b0a209776a4f6c` |
| `unit/wamr_bh_leb128.c` | (made by the script) | `fa1fbecb37ce9ef6ef0f2785b8bf69f898e633411d2af5d80b3029f028bf7b27` |
| `unit/wamr_bh_vector.c` | (made by the script) | `41e01028ab95584fdd7e49525bca148bc6af1822e6fcd6d53e8780cd4f26172e` |
| `unit/wamr_ems_alloc.c` | (made by the script) | `4b672e18df7cba1f2f4392dc0cebb6caf0e4344003b98fb554163d71ffe86ce4` |
| `unit/wamr_mem_alloc.c` | (made by the script) | `7c51027e5b8dfc7bc167f517f4c1b71db53678b7046d088e2785f179a954a86d` |
| `simde/simde-constify.h` | `08e029bce27502966e7ba0a0886e17aea3ee997f9ec25f962529364d7c7d711d` | `08e029bce27502966e7ba0a0886e17aea3ee997f9ec25f962529364d7c7d711d` |
| `simde/simde-features.h` | `8e19781bd1fc77302e9b06e8c847816a604fb2726b6f2d8629a10f46ea0205de` | `8e19781bd1fc77302e9b06e8c847816a604fb2726b6f2d8629a10f46ea0205de` |
| `unit/wamr_bh_hashmap.c` | (made by the script) | `6eb1754a9734ae98f9364b369e37cc5ce902e5df84d12abca477b170328101a5` |
| `unit/wamr_posix_time.c` | (made by the script) | `01f0ff18ebbfb50e563513ce7c9457b9106a31175ac66ce466a8e42891c2909b` |
| `unit/wamr_win_malloc.c` | (made by the script) | `86758d25964dd500d4185f82b1b280718173771936f594250721275afa505f86` |
| `unit/wamr_win_memmap.c` | (made by the script) | `ebfc8de43d1f6694fe2af70792747cc4152d470b19926cad24da87da514ec217` |
| `unit/wamr_win_thread.c` | (made by the script) | `8c51eb6f91691556f541f7d509f728f9dfa021646dcbb7a0386305cb5d1f69ca` |
| `unit/wamr_posix_sleep.c` | (made by the script) | `8fa5dfa0d7ce27728cdfd253f5d085f56efea9d0dc53eaf5757752e0101f5f26` |
| `unit/wamr_wasm_loader.c` | (made by the script) | `2915b513ab73b900c4ba81d355eab331aab21a43e92d158d9548315c3fdb602e` |
| `unit/wamr_wasm_memory.c` | (made by the script) | `6edc27d88f9538701db69e8eb197e0434644312f4bf1083671d6fb33ac36f89f` |
| `unit/wamr_wasm_native.c` | (made by the script) | `61590df3b9ae814b6c6f3b4b102ccbc8cf48dc06d0658442c170175984f93a67` |
| `core/shared/utils/gnuc.h` | `8e22c128c020e8001de02370a4655e009dd75240166b8ffd219f2ca089540580` | `8e22c128c020e8001de02370a4655e009dd75240166b8ffd219f2ca089540580` |
| `simde/simde-diagnostic.h` | `8bb67c3af2f95306368829c778b0d6ff8419867566027d10a0df4f697dec96c9` | `8bb67c3af2f95306368829c778b0d6ff8419867566027d10a0df4f697dec96c9` |
| `unit/wamr_posix_malloc.c` | (made by the script) | `4bc5839295b6ceee3244b29464f262683b425770c0fcca484f63989a96de5194` |
| `unit/wamr_posix_memmap.c` | (made by the script) | `0b86c4e04342e158d3eef5afe49cb81e7c27a51a66ed9c19bcd819763a7ad1f0` |
| `unit/wamr_posix_thread.c` | (made by the script) | `6d6c3645b96f3edc07a8ae9657f463e465677c633ab591128134845fe0ba65fa` |
| `unit/wamr_wasm_runtime.c` | (made by the script) | `81ccbaf4f34acd62368677fd5bb6d92b1209cd67e93ae88c35575d3f150275b9` |
| `unit/wamr_runtime_timer.c` | (made by the script) | `9ee0506e5c068a742b48ca400df75555b84814624cea14f31fb0935d1202df2b` |
| `unit/wamr_wasm_exec_env.c` | (made by the script) | `a144f178eae00f6fd8095a1ebc818a6a3bd80b1ff543c1f13aa884d214421567` |
| `core/shared/utils/bh_log.c` | `c4bd4e869674e7b4067c2d74110bad2299c4c1780e4474c1e1dbdde7138f4072` | `c4bd4e869674e7b4067c2d74110bad2299c4c1780e4474c1e1dbdde7138f4072` |
| `core/shared/utils/bh_log.h` | `ccaca360ef935b23e8d0a792ca88d1a4fe42060c587da85b5171a6284b745d3b` | `ccaca360ef935b23e8d0a792ca88d1a4fe42060c587da85b5171a6284b745d3b` |
| `simde/simde-detect-clang.h` | `aa20aa6ceeb69f2b675dd5ef8974ddd82db9d56570fa9570903c3f54f20a8f9f` | `aa20aa6ceeb69f2b675dd5ef8974ddd82db9d56570fa9570903c3f54f20a8f9f` |
| `unit/wamr_thread_manager.c` | (made by the script) | `4530b0569d2b3238435bb4009a8797b124137184f513149442c0b8de03afbedf` |
| `core/shared/utils/bh_list.c` | `6ed8b6b678296b7bb80cac81c8ac17abb498f9a150d2074909cb8b5bcfd9a44c` | `6ed8b6b678296b7bb80cac81c8ac17abb498f9a150d2074909cb8b5bcfd9a44c` |
| `core/shared/utils/bh_list.h` | `9575c27d6aa0b775c8e91d2dd6bd38a47a7b8bd693df72f5cfab8bca08ac1929` | `9575c27d6aa0b775c8e91d2dd6bd38a47a7b8bd693df72f5cfab8bca08ac1929` |
| `core/iwasm/aot/aot_runtime.h` | `65834f0c9247794df2771fed9cf3005701cef86cc06311c414591dd25f0e4f27` | `f165f727dd0b76a435846ec3c6240aed461e06b68f605721f957e03f659ffe2c` |
| `core/iwasm/compilation/aot.h` | `b7991daa44b3a341764730a593b72cccc8537e590a6489f9c906c45474e02771` | `fa6905bb56a40d7121404a44782259c2f30ab4b86af9ab99726f2f0de0a18f02` |
| `core/iwasm/fast-jit/jit_ir.h` | `a74ff3110c576650b069fad9ca5ffed97ae49763b3b64172448fc7f1db220022` | `fb3a8b0e8eb38deda27090ad0a6356571a1ed46d05ccef4380400b291d9d1c58` |
| `core/shared/utils/bh_queue.c` | `25dbc23b43ac673959e74252c69ed3f1229466c487a8645f12a124d1b59692d7` | `25dbc23b43ac673959e74252c69ed3f1229466c487a8645f12a124d1b59692d7` |
| `core/shared/utils/bh_queue.h` | `f4b29e1841799586de722fd59ef041dd5ab07a9f583437d45d92e40fe1d7cafc` | `f4b29e1841799586de722fd59ef041dd5ab07a9f583437d45d92e40fe1d7cafc` |
| `unit/wamr_wasm_application.c` | (made by the script) | `7a1492265b4ad9db088d1170cb6b626a54f3d666fab602b883b910b7a27d4177` |
| `unit/wamr_wasm_blocking_op.c` | (made by the script) | `cd8031a724fc1f2e59d8ab3d1cb86d77317535b812afb9c3766012390cb2d56f` |
| `unit/wamr_wasm_interp_fast.c` | (made by the script) | `f4272fa59a2f75c9899da89d056f37fb04f402c0681d0af0ff34ba2d69cb50b3` |
| `core/iwasm/interpreter/wasm.h` | `169c7c207f0595c6e736d734bdd5eff510890eff737a2c4c0eebc7d8e20be559` | `b627758d40baa4c300b3ab41fe4b863ae70023b268fb4f64ecfe38f9849cee16` |
| `core/shared/utils/bh_assert.c` | `02ed921ce838e4b28925822ebd2c7f8b56daee53a23ed715f6dda7a51cb37366` | `02ed921ce838e4b28925822ebd2c7f8b56daee53a23ed715f6dda7a51cb37366` |
| `core/shared/utils/bh_assert.h` | `37f2e291c99c5fa3696a97de236773d4a31ce36df83f6eac1e521909cd096115` | `37f2e291c99c5fa3696a97de236773d4a31ce36df83f6eac1e521909cd096115` |
| `core/shared/utils/bh_atomic.h` | `efcf825cc91ff7ed8018f84265cbff52ab71b4180cff66c1369ffd6c3d3597fe` | `efcf825cc91ff7ed8018f84265cbff52ab71b4180cff66c1369ffd6c3d3597fe` |
| `core/shared/utils/bh_bitmap.c` | `5f82d021f9cc3aa205b6f3f611899730fa183c5adf50c1af1123ad8214f33ec4` | `5f82d021f9cc3aa205b6f3f611899730fa183c5adf50c1af1123ad8214f33ec4` |
| `core/shared/utils/bh_bitmap.h` | `a228891c53c242fe7d7baf47f9516b0b020d6cf2fef7587727497c4692f2bf1f` | `a228891c53c242fe7d7baf47f9516b0b020d6cf2fef7587727497c4692f2bf1f` |
| `core/shared/utils/bh_common.c` | `8b36c82618f1ca60e3a8a4eb4c186f4f07e5a578b72f61c31d5f9bc2a8e56deb` | `8b36c82618f1ca60e3a8a4eb4c186f4f07e5a578b72f61c31d5f9bc2a8e56deb` |
| `core/shared/utils/bh_common.h` | `6ea9810270a8317baf26f3f4e0593fed001f3ee10ea0edf6082e4025042f7287` | `6ea9810270a8317baf26f3f4e0593fed001f3ee10ea0edf6082e4025042f7287` |
| `core/shared/utils/bh_leb128.c` | `b7be57ec6bc3a6e51e4b526e667d4d1e8fbd987f38a3fdabffb1cf3925cbf47d` | `b7be57ec6bc3a6e51e4b526e667d4d1e8fbd987f38a3fdabffb1cf3925cbf47d` |
| `core/shared/utils/bh_leb128.h` | `15612fa7177406656861eedf28e63356bdf8c4d9f1ca06720667367fcebc518d` | `15612fa7177406656861eedf28e63356bdf8c4d9f1ca06720667367fcebc518d` |
| `core/shared/utils/bh_vector.c` | `93fb29a31e2c9e7db7853f7d7db217075123e5bf6253f30b4b59e085b4eac48a` | `93fb29a31e2c9e7db7853f7d7db217075123e5bf6253f30b4b59e085b4eac48a` |
| `core/shared/utils/bh_vector.h` | `7508bd2d3277b2dfd9b1b8b43c71941c78a7747ca260a9208c46004aeea55e73` | `7508bd2d3277b2dfd9b1b8b43c71941c78a7747ca260a9208c46004aeea55e73` |
| `unit/wamr_posix_blocking_op.c` | (made by the script) | `5ba52a28026afdb86d3fbcfd88d1695311ebd83b8a58cd32f1b0d93bb2b2e64f` |
| `core/iwasm/common/gc/gc_type.h` | `1191bed10002cf9a980f9ad319c5ef4661cb54211a59f2d8073abf2c255dcd41` | `1b5d6e63b767165e7d7981c46fd43c8ac00fcf7abf38f7979e4053090f75e3e1` |
| `core/iwasm/include/gc_export.h` | `bec764173d7c7b8dc03e53e51160f7442d58c591c693b9ca011f564ea7a7a7f1` | `bec764173d7c7b8dc03e53e51160f7442d58c591c693b9ca011f564ea7a7a7f1` |
| `core/shared/utils/bh_hashmap.c` | `2cd78f228c97bbfd4342b97426105f27fba85bc990bddf8885d65d1cf921eb82` | `2cd78f228c97bbfd4342b97426105f27fba85bc990bddf8885d65d1cf921eb82` |
| `core/shared/utils/bh_hashmap.h` | `cfb4d0674dbf6cdf1256354b8c7fd52b87d7702c1d3facece133e90a13440c50` | `cfb4d0674dbf6cdf1256354b8c7fd52b87d7702c1d3facece133e90a13440c50` |
| `unit/wamr_wasm_loader_common.c` | (made by the script) | `c3563c4f0fab190390fbb3725c420c3e5b7516563150407651e856c04ee06c98` |
| `core/iwasm/common/wasm_memory.c` | `389c356c8bbc2a3420b98f465414528c270829e1a1c3eb28e6189e04a6b1b67b` | `e26b2872843e94213b0a3a51cb333fdd67decbca18e244415ffd301b1c87c3b4` |
| `core/iwasm/common/wasm_memory.h` | `918d55b701ce04d617ab647cad4b85c741c55d5e7d2a583bbbb226dac635260a` | `de889eb3045f30e429e63cf9359205acd06e214ac883c11c1a2671652bf5b235` |
| `core/iwasm/common/wasm_native.c` | `343cbeed430801bb45fa5f079ba56d595959604eddbe2c28ee7fa6f11d92b2e2` | `f0e517d424f151382b09a9b0147d01722a4132a86a56b0ca5986aaef02321dc0` |
| `core/iwasm/common/wasm_native.h` | `ae38abf99304810cb615e7ba25dc5072cde43b6de31826a1cd68ce5bc577c9d3` | `8c07fa51a01ebc7354bcaf748585e38a61e6a73cd2257d5ade66a06390edf7f3` |
| `core/iwasm/fast-jit/jit_utils.h` | `f46dbee98422a26ad7a488a41eeff83393aa96bb092551f53e49269898332200` | `5d23384c7bf65d6cbfd3a2a9b49474fa182b7839b21d4d047c68b2f5444481d8` |
| `core/iwasm/include/aot_export.h` | `db81b6c5f4d3d4157472222667707d9da52326d1c5a5c0e4f8919f02803573bc` | `db81b6c5f4d3d4157472222667707d9da52326d1c5a5c0e4f8919f02803573bc` |
| `core/iwasm/include/lib_export.h` | `19c182c07246c971eee6c54ddf5bd552fcb5fee91be6970681815c0d19ea1264` | `19c182c07246c971eee6c54ddf5bd552fcb5fee91be6970681815c0d19ea1264` |
| `core/iwasm/include/wasm_c_api.h` | `ddde625be452251da2efbb96b074edd2605335c86c102c9cf09947c6b3f6bcfb` | `ddde625be452251da2efbb96b074edd2605335c86c102c9cf09947c6b3f6bcfb` |
| `core/shared/utils/bh_platform.h` | `e556979ba3fe1fdc4b261233aee1867757e72103083adc5b15f4cea9049ea286` | `e556979ba3fe1fdc4b261233aee1867757e72103083adc5b15f4cea9049ea286` |
| `unit/wamr_platform_init_linux.c` | (made by the script) | `0f7a31d62570ac2b65e12e20565ed80d11062c635480eeb8ee972b4ff3fc2eb7` |
| `unit/wamr_wasm_runtime_common.c` | (made by the script) | `f6df89e65f10f12da772367f060e2f454a8ac2d908a5aa2e1d553434b12134d3` |
| `core/iwasm/aot/debug/jit_debug.h` | `fbe3b5e18c88cdc10714caf15b38c36457cf96c99f7b7b488c627194aad232cb` | `fbe3b5e18c88cdc10714caf15b38c36457cf96c99f7b7b488c627194aad232cb` |
| `core/iwasm/common/gc/gc_object.h` | `5e5d1043bfca8607db78825274878b444008c0dd20d151f4a5d293cf04e26100` | `5e5d1043bfca8607db78825274878b444008c0dd20d151f4a5d293cf04e26100` |
| `core/iwasm/include/wasm_export.h` | `779ee0870da26f129afe26f58881d286e0bef1537d995acf9cdd27c8a50c3ee0` | `779ee0870da26f129afe26f58881d286e0bef1537d995acf9cdd27c8a50c3ee0` |
| `unit/wamr_platform_init_darwin.c` | (made by the script) | `957b9feb1a2c9733495cada001db9eb4aa77c5b7325f664a22030c25f2c64213` |
| `core/iwasm/common/wasm_exec_env.c` | `6e42bc3ccf2e3096e3b7e814f4e69d49db6f1c9a7994ba1c1abdd2ca4ae2ec75` | `bf7f2df55ed5dc7e6f2282e80b8ab91cb0c8ec412b864d196a81a6296ed2515c` |
| `core/iwasm/common/wasm_exec_env.h` | `13cba0073a968e17a3a0b5a0ec5911f788688134827bc182ad0287c2e408799a` | `2d519226a5da0d73c64db49b2c0316bae1db00567a39cb21fedf71b10d9f93dc` |
| `core/iwasm/compilation/aot_llvm.h` | `0a4ba697bdbd08f162bf7bc70af5f09bf78c76c89ce679eabb597156b0af65cf` | `edfcad7c352441c36570803cd30475f8b7fb2347971bd593cac374a7b8f6526c` |
| `core/shared/mem-alloc/mem_alloc.c` | `e6c82a1114f2a95b1d3ac1aacac8b463af3a50e79eccdf29f3641e60ff35eab9` | `e6c82a1114f2a95b1d3ac1aacac8b463af3a50e79eccdf29f3641e60ff35eab9` |
| `core/shared/mem-alloc/mem_alloc.h` | `cdbf6af71ebee165463a8e212202deb2b0e588b924a1a59418ab18083fb1a296` | `b30c223a9c6b5a90fab75acbc76db078712b8cebde380cd016e36513914094c1` |
| `core/shared/utils/runtime_timer.c` | `ebd475f34e580156f9b3c47e97d7de04f5bd5dd737f6eb38f2a514b351e66a26` | `ebd475f34e580156f9b3c47e97d7de04f5bd5dd737f6eb38f2a514b351e66a26` |
| `core/shared/utils/runtime_timer.h` | `7879705d2e319d94b4a786411c9020d9558c8bbf17164b66618109603fdee84d` | `7879705d2e319d94b4a786411c9020d9558c8bbf17164b66618109603fdee84d` |
| `unit/wamr_platform_init_windows.c` | (made by the script) | `6bd42011742b49af9ab03a58c6e70846eb09d0d8c04a553f5cb5b2d2f7e031e1` |
| `core/iwasm/fast-jit/jit_compiler.h` | `466fe094c2f47adf4a01179c6aab46f30ace92de934d9c257be1895d36cafaff` | `b9229831a4c63db173b4aa08860401afa1100ac51784363ca913ca764f28c503` |
| `core/shared/mem-alloc/ems/ems_gc.c` | `baa7b39fddbafe6e3676ca4a87cf120c6cbf5df3626e90845cac53387e22a6f2` | `baa7b39fddbafe6e3676ca4a87cf120c6cbf5df3626e90845cac53387e22a6f2` |
| `core/shared/mem-alloc/ems/ems_gc.h` | `63dd5dca7ef0419ed01ca24abcf0ec1d440720fb4409d3bb8e751ec52a69bd45` | `f3a3965c0d7be8a8c7b581fe6059a8a84f4bd716d66c182a50a8b36c5dda9f4b` |
| `core/iwasm/fast-jit/jit_codecache.h` | `fa56086cf6c06617d1c88b1ecf11521522288bcb3ecf78715b40306640e9dd2a` | `7b05ad8ca6167b4a1588fbb78d25466633c0aa3a3b0a5ec67374b8a893382a34` |
| `core/shared/mem-alloc/ems/ems_hmu.c` | `18dc2301cb147ee48ade1038cda510b386ee7a84cf1cd11bea3dfbc81035a89f` | `18dc2301cb147ee48ade1038cda510b386ee7a84cf1cd11bea3dfbc81035a89f` |
| `core/shared/mem-alloc/ems/ems_kfc.c` | `2a6f6985b9416fff337d3ea29ba2d38dd783c364a580e0e526404151e4427a2d` | `2a6f6985b9416fff337d3ea29ba2d38dd783c364a580e0e526404151e4427a2d` |
| `core/iwasm/common/wasm_application.c` | `0140952ceb8236b974887c4d8c19d403f77dc1f44c0db92b8aa3f87a9a64a45f` | `0d22d7fabd8241b2f716e6480bd027abda15839dce1f0b280f4b09da620091eb` |
| `core/iwasm/common/wasm_blocking_op.c` | `9f04390ba760ddeeb84b32542eea1edff20eb6321e9ff09d2fa6bdf137ec2b8c` | `87fc35deaf012324b46ac1ae40846f9af7847098f649b8e9fd260f836631a3d5` |
| `core/iwasm/include/aot_comp_option.h` | `821a541c18488b5e9ea114f0b78173519f458048452ebd2c0380aa6383c31114` | `821a541c18488b5e9ea114f0b78173519f458048452ebd2c0380aa6383c31114` |
| `core/iwasm/interpreter/wasm_interp.h` | `2a30ae85f8b52d9a10f4a222164a5e06c35e4645862955269d72367c73d79411` | `2a30ae85f8b52d9a10f4a222164a5e06c35e4645862955269d72367c73d79411` |
| `core/iwasm/interpreter/wasm_loader.c` | `5b932606560fc6e533a0b8c85c0f643c1b60bfcef6b883b20e0bbfc1ffd9852a` | `4cf97529d7177cb66aedcec8fe0be4962d3f267c2088207b7afdfda14a850c74` |
| `core/iwasm/interpreter/wasm_loader.h` | `ec1b800bc78c2f0180f8b0043928e93a810ee785487a14c22dbb001ed5942398` | `b5a4b9ee79e45d69fd34e77cd29e7fb0468290c6f43d7dad84396d7e6588bdb2` |
| `core/iwasm/interpreter/wasm_opcode.h` | `f490e2617466f37b7dcf96f811218b0a2402196f05b3fb5d1c3ed49ca2a281e2` | `f490e2617466f37b7dcf96f811218b0a2402196f05b3fb5d1c3ed49ca2a281e2` |
| `core/iwasm/interpreter/wasm_runtime.c` | `462f8ed5ffb588caeece79ecc82094d8796be563af2fc14b2436d5551a3b87e9` | `92a8df6138b302cabcd970d473c231e3f775e0190339708bd05d522dcc32de8d` |
| `core/iwasm/interpreter/wasm_runtime.h` | `6a299718da228cc27c4428dc592f78f2c0f6fb4e4514295d1b1915bd81a1be69` | `053cf3ba9570bed2cbfe5247bf92ada3c4100b6ad4710624381580c190e07f35` |
| `core/shared/mem-alloc/ems/ems_alloc.c` | `f630bf416cc73f12d9385cab30ade05782d8d60792a811e550938b005fd9eba6` | `f630bf416cc73f12d9385cab30ade05782d8d60792a811e550938b005fd9eba6` |
| `core/iwasm/common/wasm_loader_common.c` | `e579fcaad2371effcd51ad49402172f86727f7ccb60bfcfbfc66501b7f2d351d` | `3afbca4f5e3374056f431471e586cc2bfcff651b8dda4078d6469551b1e777e8` |
| `core/iwasm/common/wasm_loader_common.h` | `8e3c82af318f153686cdf27c6b60184edbdc901eb8ce2abb0f742eb7f6c62a96` | `09b49f6c72958a1680a300893884bc70e4faa2e3013e9ba96bcb2ceb2341d7d1` |
| `core/iwasm/common/wasm_shared_memory.h` | `dc0cfb3bbf506b0a5ddf0fa330796aa74ae2dc201fb8dfc2a2531b6e61427b99` | `f201400571aa8bd0e8aaca00166964ebf6e0d46d9755b1a4a4d0cc7f39b15d68` |
| `core/iwasm/common/wasm_suspend_flags.h` | `5cbce685f3d471c077fdbf4b2405e5f07f2a5533c7cc0c4dfec55fedeb4ff168` | `f0caf9841eb9a765c5ac13ef7d236aa1a5dbcf7616ca8df1eb40052ec95f2095` |
| `core/iwasm/compilation/aot_orc_extra.h` | `f9947b433aec8c818e1c269b94d0df8907c040a875af69aa1b7d819b6e23bc14` | `f9947b433aec8c818e1c269b94d0df8907c040a875af69aa1b7d819b6e23bc14` |
| `core/iwasm/common/wasm_c_api_internal.h` | `100eb99ef20678dd204eebfe3bd9823264598d6f4ec89683dedd838b7fea0985` | `100eb99ef20678dd204eebfe3bd9823264598d6f4ec89683dedd838b7fea0985` |
| `core/iwasm/common/wasm_runtime_common.c` | `d2f8ce6f2a826e0bf8c733309e61f62597b446d33f66d8eab04d67625719e4e7` | `73d4c48d8d39a0e5153e040961e8cda2368b43434a46ca17b4f898d1db1a2d61` |
| `core/iwasm/common/wasm_runtime_common.h` | `baa2c611d4caea774698e4d3e7f368c68d72c2bbb99cf3fb6d1744ed64688d28` | `912c0b0adbe070193620c47f6f7fe46a94a5e8bb4ceec1f3c6601902d3a310cf` |
| `core/shared/platform/windows/win_time.c` | `a59617466df837978757a82b03baa89f3c086493b89d7fc2adb4d6111a8d65b0` | `c25429ccef184af0ccb3996cda6b66d3ecf68d0f6f0eb682eb1f73149e0fed1c` |
| `core/shared/platform/windows/win_util.c` | `c79600c2b9e1b254cbaf3e643af20c35f4b550bba3738b2fd1aa9ca3dead1810` | `8a3dd60a09096eb6b609055b1f0074e95484bfb3bf0fc4f65451c9b274ad5df5` |
| `core/shared/platform/windows/win_util.h` | `c7866b30196149d2dfcad73abded41481044401c1e7fc2a8b20ad9f48f7c8e58` | `eb51f7bd1d1ec33bf7c286e285069c82cf0738e7d0a56ea57cffbbbe7026adf8` |
| `core/iwasm/interpreter/wasm_interp_fast.c` | `a7f4144168ff6e838d268b7b0b8425c7fa06482fa2f464c3f5d7f9a8ea72cb32` | `14d0a99c57dd1185e674d7d72261d214d028c33b786901b5a414cfcc9e522fbd` |
| `core/shared/platform/windows/win_malloc.c` | `9d59f596e75d23eee11e944800c1686a3081c60b87de1ba016310c17061fa06f` | `c277f9ae707ebeae01bf3206bb1b6d458dc44a01eaa618ca0c08666a83c25a90` |
| `core/shared/platform/windows/win_memmap.c` | `9c2ef388721d5639537bffb376603d2a603766d016a546f34c6d6c517fb41b30` | `c2ba5e5ef132b05d85339073fb6646cc16e25b40f9175416dfb34a695405040e` |
| `core/shared/platform/windows/win_thread.c` | `6066a1b91de8a29356b32eec737c955a1ab2f9e86f3538c31657b8d8bfc00dce` | `964b85211abdb679457467faac08a29017660939e5c6e53e5dd61ca640a8d266` |
| `core/shared/platform/linux/platform_init.c` | `648aa47378ff459debbe91f5d0985227790dae50b325c235f9627251eea29338` | `f994df6239ce7662d9bc7903045066a0a420f685e337527e2365e9ffa8ec035b` |
| `core/shared/mem-alloc/ems/ems_gc_internal.h` | `70dadb6b881fae264ee02988f3716262024765417f12ec905076d29ca57ec421` | `8326f73c69fa723a96506c64b9da36739bbb7e29715865d1e625550a368b43ea` |
| `core/shared/platform/common/memory/mremap.c` | `2a4f7bbe37bb8cf379619ad8e7b2c06fc0c70a10cbd32122596353f489c3d535` | `d387e6c8baa39883dbb78d2bdf28abb04697199e3f3aba752ef99d371d226f7f` |
| `core/shared/platform/darwin/platform_init.c` | `648aa47378ff459debbe91f5d0985227790dae50b325c235f9627251eea29338` | `f994df6239ce7662d9bc7903045066a0a420f685e337527e2365e9ffa8ec035b` |
| `core/shared/platform/windows/platform_init.c` | `a6a8dd3c6c9b3bd4091eb2e90ccf54736a85a6dcd6f4e0891a1b57e30b2143c5` | `eb5af2ad0b8db82aafefff89d45bdc5140e670a5f3842eb77753b4aa0279fbde` |
| `core/iwasm/libraries/debug-engine/gdbserver.h` | `9adca1792e004ab52080551da5537ba86d65cd0858ac20121071986037064edd` | `1c61ddd9de6dd566b7140fbd86fb55815b6721e4c1cc11262e4ff166073016fd` |
| `core/shared/platform/common/posix/posix_time.c` | `0a9e428230064fb0ec97b248b44f3be3d9ec0938f2aca9e2caf90acb960ef4e1` | `028a132caeb46452efbcf169f420f8c379910e7920736dfc93c814ec0cc3e03c` |
| `core/shared/platform/include/platform_common.h` | `c1804e24b09f26d934949ff4ab76bc9e56b234167ad679f84ecb8dfb908a137d` | `fd8fe2c77566689e03fd454ec429a141261db488612d8bd15e2a96508d48ba90` |
| `core/shared/platform/linux/platform_internal.h` | `2f8b9fdb92d9cc7701203cfd5ae5d32f2bcb4ac44620610aea7e0a8724f43a76` | `2f8b9fdb92d9cc7701203cfd5ae5d32f2bcb4ac44620610aea7e0a8724f43a76` |
| `core/shared/platform/common/posix/posix_sleep.c` | `8d187e7a6324f75d7d41ed618e380255dd5df83ccb9acfaaa591094646a91f77` | `04e2663300fab6e5503f8136c39359d7f6f0cac08fb9eaf45d80fe60b894c3c3` |
| `core/shared/platform/darwin/platform_internal.h` | `0bdade03e3fc76a17d1ff943058df4077baaf7e944d3e872e08152eb03f947e4` | `0bdade03e3fc76a17d1ff943058df4077baaf7e944d3e872e08152eb03f947e4` |
| `core/iwasm/libraries/debug-engine/debug_engine.h` | `7d96f28f0f8246eed0338303156141048f26e3c7b61816890633da77c9dc399f` | `fd7e5f6a141ff2e904d76f6c81b38bbee749b88d2c1eaeac34718160cb40d36f` |
| `core/iwasm/libraries/thread-mgr/thread_manager.c` | `9ed794b18f413bc8ee1a98011f8003c3ed2b728912846d8dd373287f1b92b9ab` | `ca5ea28f0b5cc9ce5909d6dbdf8c4623e7d014b4dcac0683d987cc913c393589` |
| `core/iwasm/libraries/thread-mgr/thread_manager.h` | `e35a08b2d7d6a0c6176b0798c4e3c4ea0e7576567c18bf9d2c8a7377f7a2a40d` | `d7dd7376cd71280e7cc0ed2035bdaae7655ac6eb9b69199c332048bd34463900` |
| `core/shared/platform/common/posix/posix_malloc.c` | `94cab157fe5a8cadedddeff7e6ba913b1fd75d837260cd1aa856ec24214c5793` | `ea7ce0cd2bc0c5912a0f0c323e734be98c687bb02e5bcbf156cc0b974a95eea8` |
| `core/shared/platform/common/posix/posix_memmap.c` | `5fc9ddbca5737c77748ebed4f65a0d7d4610ee1ae26c568102aa190f1f508a33` | `e3f199c3d4d693e2de7793a0eee35af911e0c68441e9e96ca8c9e7ce94b24c0f` |
| `core/shared/platform/common/posix/posix_thread.c` | `bdf8a92c27729e06b856e96736e3b56a7085da5a70330331edf3ee9d1120f17d` | `1095c5fcf5f2a5eb20b15f65455a9ae83f2657f7e281c6d437f62e1644d27b09` |
| `core/shared/platform/windows/platform_internal.h` | `6cf67988a445aff175fe94a667deeb25109cf07ea847d5e447ba3807c1869800` | `b7826f300624be57b88e2c491d6d516934c55c42ec93d37208823b6cfe055eba` |
| `core/shared/platform/include/platform_api_vmcore.h` | `4be5dbfcd0e5aebcdb530ee7e01880eecc00ce5ecd8560da2b1a6eefdda4330b` | `86a505a5891110f1299cdbbc89a028399889cbff657dc4166773a550eb7103ca` |
| `core/shared/platform/include/platform_wasi_types.h` | `d3b2978f3b38d77c50e693dc93c0cba20ec7021859878bdc58f69c0cc790ca91` | `d3b2978f3b38d77c50e693dc93c0cba20ec7021859878bdc58f69c0cc790ca91` |
| `core/shared/platform/common/posix/posix_blocking_op.c` | `90f188f99e2f4bb7941a04e41cd3d021f6484b360f58fe45a90be3fb90d7cd9c` | `7c4619d197ef6a1232fef6fa065e59ce2e21e0a6a96f73ff49c56f126412f58b` |
| `core/shared/platform/include/platform_api_extension.h` | `5e060942fee31335df406039f87f4b829d7f97f94aebe7dceb69fd4a86d70655` | `98b4b8cae9304aff75df1f93d522973497e64db3e21f7bb162f9a86dbeeafee3` |
