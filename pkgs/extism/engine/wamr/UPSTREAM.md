# Vendored WAMR

The C source of the WebAssembly Micro Runtime (WAMR) that the native engine builds, from
https://github.com/bytecodealliance/wasm-micro-runtime. License: Apache-2.0 WITH LLVM-exception
(`LICENSE`).

Do not edit the files under `core/` or `unit/`: `scripts/vendor-wamr.mbtx` writes them. It copies the
files with their layout and rewrites each quoted `#include` that WAMR resolves through an include
directory of its CMake build into a path relative to the including file, so that the engine
builds with no include path. `extism_config.h` holds the build settings.
- Tag: `WAMR-2.4.5`
- Commit: `25bd7eb63e828e4bd242cc9b38d260b4b31c6605`

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

## Files and the SHA-256 of each upstream file

| File | SHA-256 |
| --- | --- |
| `core/config.h` | `589dabe8ca01f472b744576593d7371b37c174524b2eb307e26c0296002dcc06` |
| `core/version.h` | `01f4cf6e441e0372b5c70d685f6d803a00c4a1b2c3c72e4edf8014e91b951c65` |
| `core/shared/utils/gnuc.h` | `8e22c128c020e8001de02370a4655e009dd75240166b8ffd219f2ca089540580` |
| `core/shared/utils/bh_log.c` | `c4bd4e869674e7b4067c2d74110bad2299c4c1780e4474c1e1dbdde7138f4072` |
| `core/shared/utils/bh_log.h` | `ccaca360ef935b23e8d0a792ca88d1a4fe42060c587da85b5171a6284b745d3b` |
| `core/shared/utils/bh_list.c` | `6ed8b6b678296b7bb80cac81c8ac17abb498f9a150d2074909cb8b5bcfd9a44c` |
| `core/shared/utils/bh_list.h` | `9575c27d6aa0b775c8e91d2dd6bd38a47a7b8bd693df72f5cfab8bca08ac1929` |
| `core/iwasm/aot/aot_runtime.h` | `65834f0c9247794df2771fed9cf3005701cef86cc06311c414591dd25f0e4f27` |
| `core/iwasm/compilation/aot.h` | `b7991daa44b3a341764730a593b72cccc8537e590a6489f9c906c45474e02771` |
| `core/iwasm/fast-jit/jit_ir.h` | `a74ff3110c576650b069fad9ca5ffed97ae49763b3b64172448fc7f1db220022` |
| `core/shared/utils/bh_queue.c` | `25dbc23b43ac673959e74252c69ed3f1229466c487a8645f12a124d1b59692d7` |
| `core/shared/utils/bh_queue.h` | `f4b29e1841799586de722fd59ef041dd5ab07a9f583437d45d92e40fe1d7cafc` |
| `core/iwasm/interpreter/wasm.h` | `169c7c207f0595c6e736d734bdd5eff510890eff737a2c4c0eebc7d8e20be559` |
| `core/shared/utils/bh_assert.c` | `02ed921ce838e4b28925822ebd2c7f8b56daee53a23ed715f6dda7a51cb37366` |
| `core/shared/utils/bh_assert.h` | `37f2e291c99c5fa3696a97de236773d4a31ce36df83f6eac1e521909cd096115` |
| `core/shared/utils/bh_atomic.h` | `efcf825cc91ff7ed8018f84265cbff52ab71b4180cff66c1369ffd6c3d3597fe` |
| `core/shared/utils/bh_bitmap.c` | `5f82d021f9cc3aa205b6f3f611899730fa183c5adf50c1af1123ad8214f33ec4` |
| `core/shared/utils/bh_bitmap.h` | `a228891c53c242fe7d7baf47f9516b0b020d6cf2fef7587727497c4692f2bf1f` |
| `core/shared/utils/bh_common.c` | `8b36c82618f1ca60e3a8a4eb4c186f4f07e5a578b72f61c31d5f9bc2a8e56deb` |
| `core/shared/utils/bh_common.h` | `6ea9810270a8317baf26f3f4e0593fed001f3ee10ea0edf6082e4025042f7287` |
| `core/shared/utils/bh_leb128.c` | `b7be57ec6bc3a6e51e4b526e667d4d1e8fbd987f38a3fdabffb1cf3925cbf47d` |
| `core/shared/utils/bh_leb128.h` | `15612fa7177406656861eedf28e63356bdf8c4d9f1ca06720667367fcebc518d` |
| `core/shared/utils/bh_vector.c` | `93fb29a31e2c9e7db7853f7d7db217075123e5bf6253f30b4b59e085b4eac48a` |
| `core/shared/utils/bh_vector.h` | `7508bd2d3277b2dfd9b1b8b43c71941c78a7747ca260a9208c46004aeea55e73` |
| `core/iwasm/common/gc/gc_type.h` | `1191bed10002cf9a980f9ad319c5ef4661cb54211a59f2d8073abf2c255dcd41` |
| `core/iwasm/include/gc_export.h` | `bec764173d7c7b8dc03e53e51160f7442d58c591c693b9ca011f564ea7a7a7f1` |
| `core/shared/utils/bh_hashmap.c` | `2cd78f228c97bbfd4342b97426105f27fba85bc990bddf8885d65d1cf921eb82` |
| `core/shared/utils/bh_hashmap.h` | `cfb4d0674dbf6cdf1256354b8c7fd52b87d7702c1d3facece133e90a13440c50` |
| `core/iwasm/common/wasm_memory.c` | `389c356c8bbc2a3420b98f465414528c270829e1a1c3eb28e6189e04a6b1b67b` |
| `core/iwasm/common/wasm_memory.h` | `918d55b701ce04d617ab647cad4b85c741c55d5e7d2a583bbbb226dac635260a` |
| `core/iwasm/common/wasm_native.c` | `343cbeed430801bb45fa5f079ba56d595959604eddbe2c28ee7fa6f11d92b2e2` |
| `core/iwasm/common/wasm_native.h` | `ae38abf99304810cb615e7ba25dc5072cde43b6de31826a1cd68ce5bc577c9d3` |
| `core/iwasm/fast-jit/jit_utils.h` | `f46dbee98422a26ad7a488a41eeff83393aa96bb092551f53e49269898332200` |
| `core/iwasm/include/aot_export.h` | `db81b6c5f4d3d4157472222667707d9da52326d1c5a5c0e4f8919f02803573bc` |
| `core/iwasm/include/lib_export.h` | `19c182c07246c971eee6c54ddf5bd552fcb5fee91be6970681815c0d19ea1264` |
| `core/iwasm/include/wasm_c_api.h` | `ddde625be452251da2efbb96b074edd2605335c86c102c9cf09947c6b3f6bcfb` |
| `core/shared/utils/bh_platform.h` | `e556979ba3fe1fdc4b261233aee1867757e72103083adc5b15f4cea9049ea286` |
| `core/iwasm/aot/debug/jit_debug.h` | `fbe3b5e18c88cdc10714caf15b38c36457cf96c99f7b7b488c627194aad232cb` |
| `core/iwasm/common/gc/gc_object.h` | `5e5d1043bfca8607db78825274878b444008c0dd20d151f4a5d293cf04e26100` |
| `core/iwasm/include/wasm_export.h` | `779ee0870da26f129afe26f58881d286e0bef1537d995acf9cdd27c8a50c3ee0` |
| `core/iwasm/common/wasm_exec_env.c` | `6e42bc3ccf2e3096e3b7e814f4e69d49db6f1c9a7994ba1c1abdd2ca4ae2ec75` |
| `core/iwasm/common/wasm_exec_env.h` | `13cba0073a968e17a3a0b5a0ec5911f788688134827bc182ad0287c2e408799a` |
| `core/iwasm/compilation/aot_llvm.h` | `0a4ba697bdbd08f162bf7bc70af5f09bf78c76c89ce679eabb597156b0af65cf` |
| `core/shared/mem-alloc/mem_alloc.c` | `e6c82a1114f2a95b1d3ac1aacac8b463af3a50e79eccdf29f3641e60ff35eab9` |
| `core/shared/mem-alloc/mem_alloc.h` | `cdbf6af71ebee165463a8e212202deb2b0e588b924a1a59418ab18083fb1a296` |
| `core/shared/utils/runtime_timer.c` | `ebd475f34e580156f9b3c47e97d7de04f5bd5dd737f6eb38f2a514b351e66a26` |
| `core/shared/utils/runtime_timer.h` | `7879705d2e319d94b4a786411c9020d9558c8bbf17164b66618109603fdee84d` |
| `core/iwasm/fast-jit/jit_compiler.h` | `466fe094c2f47adf4a01179c6aab46f30ace92de934d9c257be1895d36cafaff` |
| `core/shared/mem-alloc/ems/ems_gc.c` | `baa7b39fddbafe6e3676ca4a87cf120c6cbf5df3626e90845cac53387e22a6f2` |
| `core/shared/mem-alloc/ems/ems_gc.h` | `63dd5dca7ef0419ed01ca24abcf0ec1d440720fb4409d3bb8e751ec52a69bd45` |
| `core/iwasm/fast-jit/jit_codecache.h` | `fa56086cf6c06617d1c88b1ecf11521522288bcb3ecf78715b40306640e9dd2a` |
| `core/shared/mem-alloc/ems/ems_hmu.c` | `18dc2301cb147ee48ade1038cda510b386ee7a84cf1cd11bea3dfbc81035a89f` |
| `core/shared/mem-alloc/ems/ems_kfc.c` | `2a6f6985b9416fff337d3ea29ba2d38dd783c364a580e0e526404151e4427a2d` |
| `core/iwasm/common/wasm_application.c` | `0140952ceb8236b974887c4d8c19d403f77dc1f44c0db92b8aa3f87a9a64a45f` |
| `core/iwasm/common/wasm_blocking_op.c` | `9f04390ba760ddeeb84b32542eea1edff20eb6321e9ff09d2fa6bdf137ec2b8c` |
| `core/iwasm/include/aot_comp_option.h` | `821a541c18488b5e9ea114f0b78173519f458048452ebd2c0380aa6383c31114` |
| `core/iwasm/interpreter/wasm_interp.h` | `2a30ae85f8b52d9a10f4a222164a5e06c35e4645862955269d72367c73d79411` |
| `core/iwasm/interpreter/wasm_loader.c` | `5b932606560fc6e533a0b8c85c0f643c1b60bfcef6b883b20e0bbfc1ffd9852a` |
| `core/iwasm/interpreter/wasm_loader.h` | `ec1b800bc78c2f0180f8b0043928e93a810ee785487a14c22dbb001ed5942398` |
| `core/iwasm/interpreter/wasm_opcode.h` | `f490e2617466f37b7dcf96f811218b0a2402196f05b3fb5d1c3ed49ca2a281e2` |
| `core/iwasm/interpreter/wasm_runtime.c` | `462f8ed5ffb588caeece79ecc82094d8796be563af2fc14b2436d5551a3b87e9` |
| `core/iwasm/interpreter/wasm_runtime.h` | `6a299718da228cc27c4428dc592f78f2c0f6fb4e4514295d1b1915bd81a1be69` |
| `core/shared/mem-alloc/ems/ems_alloc.c` | `f630bf416cc73f12d9385cab30ade05782d8d60792a811e550938b005fd9eba6` |
| `core/iwasm/common/wasm_loader_common.c` | `e579fcaad2371effcd51ad49402172f86727f7ccb60bfcfbfc66501b7f2d351d` |
| `core/iwasm/common/wasm_loader_common.h` | `8e3c82af318f153686cdf27c6b60184edbdc901eb8ce2abb0f742eb7f6c62a96` |
| `core/iwasm/common/wasm_shared_memory.h` | `dc0cfb3bbf506b0a5ddf0fa330796aa74ae2dc201fb8dfc2a2531b6e61427b99` |
| `core/iwasm/common/wasm_suspend_flags.h` | `5cbce685f3d471c077fdbf4b2405e5f07f2a5533c7cc0c4dfec55fedeb4ff168` |
| `core/iwasm/compilation/aot_orc_extra.h` | `f9947b433aec8c818e1c269b94d0df8907c040a875af69aa1b7d819b6e23bc14` |
| `core/iwasm/common/wasm_c_api_internal.h` | `100eb99ef20678dd204eebfe3bd9823264598d6f4ec89683dedd838b7fea0985` |
| `core/iwasm/common/wasm_runtime_common.c` | `d2f8ce6f2a826e0bf8c733309e61f62597b446d33f66d8eab04d67625719e4e7` |
| `core/iwasm/common/wasm_runtime_common.h` | `baa2c611d4caea774698e4d3e7f368c68d72c2bbb99cf3fb6d1744ed64688d28` |
| `core/shared/platform/windows/win_time.c` | `a59617466df837978757a82b03baa89f3c086493b89d7fc2adb4d6111a8d65b0` |
| `core/shared/platform/windows/win_util.c` | `c79600c2b9e1b254cbaf3e643af20c35f4b550bba3738b2fd1aa9ca3dead1810` |
| `core/shared/platform/windows/win_util.h` | `c7866b30196149d2dfcad73abded41481044401c1e7fc2a8b20ad9f48f7c8e58` |
| `core/iwasm/interpreter/wasm_interp_fast.c` | `a7f4144168ff6e838d268b7b0b8425c7fa06482fa2f464c3f5d7f9a8ea72cb32` |
| `core/shared/platform/windows/win_malloc.c` | `9d59f596e75d23eee11e944800c1686a3081c60b87de1ba016310c17061fa06f` |
| `core/shared/platform/windows/win_memmap.c` | `9c2ef388721d5639537bffb376603d2a603766d016a546f34c6d6c517fb41b30` |
| `core/shared/platform/windows/win_thread.c` | `6066a1b91de8a29356b32eec737c955a1ab2f9e86f3538c31657b8d8bfc00dce` |
| `core/shared/platform/linux/platform_init.c` | `648aa47378ff459debbe91f5d0985227790dae50b325c235f9627251eea29338` |
| `core/shared/mem-alloc/ems/ems_gc_internal.h` | `70dadb6b881fae264ee02988f3716262024765417f12ec905076d29ca57ec421` |
| `core/shared/platform/common/memory/mremap.c` | `2a4f7bbe37bb8cf379619ad8e7b2c06fc0c70a10cbd32122596353f489c3d535` |
| `core/shared/platform/darwin/platform_init.c` | `648aa47378ff459debbe91f5d0985227790dae50b325c235f9627251eea29338` |
| `core/shared/platform/windows/platform_init.c` | `a6a8dd3c6c9b3bd4091eb2e90ccf54736a85a6dcd6f4e0891a1b57e30b2143c5` |
| `core/iwasm/libraries/debug-engine/gdbserver.h` | `9adca1792e004ab52080551da5537ba86d65cd0858ac20121071986037064edd` |
| `core/shared/platform/common/posix/posix_time.c` | `0a9e428230064fb0ec97b248b44f3be3d9ec0938f2aca9e2caf90acb960ef4e1` |
| `core/shared/platform/include/platform_common.h` | `c1804e24b09f26d934949ff4ab76bc9e56b234167ad679f84ecb8dfb908a137d` |
| `core/shared/platform/linux/platform_internal.h` | `2f8b9fdb92d9cc7701203cfd5ae5d32f2bcb4ac44620610aea7e0a8724f43a76` |
| `core/shared/platform/common/posix/posix_sleep.c` | `8d187e7a6324f75d7d41ed618e380255dd5df83ccb9acfaaa591094646a91f77` |
| `core/shared/platform/darwin/platform_internal.h` | `0bdade03e3fc76a17d1ff943058df4077baaf7e944d3e872e08152eb03f947e4` |
| `core/iwasm/libraries/debug-engine/debug_engine.h` | `7d96f28f0f8246eed0338303156141048f26e3c7b61816890633da77c9dc399f` |
| `core/iwasm/libraries/thread-mgr/thread_manager.c` | `9ed794b18f413bc8ee1a98011f8003c3ed2b728912846d8dd373287f1b92b9ab` |
| `core/iwasm/libraries/thread-mgr/thread_manager.h` | `e35a08b2d7d6a0c6176b0798c4e3c4ea0e7576567c18bf9d2c8a7377f7a2a40d` |
| `core/shared/platform/common/posix/posix_malloc.c` | `94cab157fe5a8cadedddeff7e6ba913b1fd75d837260cd1aa856ec24214c5793` |
| `core/shared/platform/common/posix/posix_memmap.c` | `5fc9ddbca5737c77748ebed4f65a0d7d4610ee1ae26c568102aa190f1f508a33` |
| `core/shared/platform/common/posix/posix_thread.c` | `bdf8a92c27729e06b856e96736e3b56a7085da5a70330331edf3ee9d1120f17d` |
| `core/shared/platform/windows/platform_internal.h` | `6cf67988a445aff175fe94a667deeb25109cf07ea847d5e447ba3807c1869800` |
| `core/shared/platform/include/platform_api_vmcore.h` | `4be5dbfcd0e5aebcdb530ee7e01880eecc00ce5ecd8560da2b1a6eefdda4330b` |
| `core/shared/platform/include/platform_wasi_types.h` | `d3b2978f3b38d77c50e693dc93c0cba20ec7021859878bdc58f69c0cc790ca91` |
| `core/shared/platform/common/posix/posix_blocking_op.c` | `90f188f99e2f4bb7941a04e41cd3d021f6484b360f58fe45a90be3fb90d7cd9c` |
| `core/shared/platform/include/platform_api_extension.h` | `5e060942fee31335df406039f87f4b829d7f97f94aebe7dceb69fd4a86d70655` |
