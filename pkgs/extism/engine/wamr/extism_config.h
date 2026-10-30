/*
 * The WAMR build settings of the moonrockz/extism engine (design ENG-2 and ENG-4).
 *
 * Every translation unit in unit/ includes this file before its WAMR source, so the build needs no -D
 * flag and no include path. The settings follow WAMR's CMake options; core/config.h gives the defaults
 * of the rest.
 */
#ifndef EXTISM_CONFIG_H
#define EXTISM_CONFIG_H

/* The fast interpreter only: no AOT and no JIT. */
#define WASM_ENABLE_INTERP 1
#define WASM_ENABLE_FAST_INTERP 1
#define WASM_ENABLE_AOT 0
#define WASM_ENABLE_JIT 0
#define WASM_ENABLE_FAST_JIT 0
#define WASM_ENABLE_LAZY_JIT 0
#define WASM_ENABLE_MINI_LOADER 0

/* No libc of WAMR: the WASI sandbox is the moonrockz/extism/wasi package. */
#define WASM_ENABLE_LIBC_BUILTIN 0
#define WASM_ENABLE_LIBC_WASI 0
#define WASM_ENABLE_LIBC_UVWASI 0

/* Features: bulk memory and reference types, as the Morphir Python extension needs; no SIMD (the
   EXT-2 gate passed without it), no shared memory, no threads, no memory64, no GC, no exceptions,
   no tail calls. */
#define WASM_ENABLE_BULK_MEMORY 1
#define WASM_ENABLE_REF_TYPES 1
#define WASM_ENABLE_SIMD 0
#define WASM_ENABLE_SHARED_MEMORY 0
#define WASM_ENABLE_LIB_PTHREAD 0
#define WASM_ENABLE_LIB_WASI_THREADS 0
#define WASM_ENABLE_MEMORY64 0
#define WASM_ENABLE_MULTI_MEMORY 0
#define WASM_ENABLE_GC 0
#define WASM_ENABLE_EXCE_HANDLING 0
#define WASM_ENABLE_TAIL_CALL 0

/* Linking: every host import is a raw native that the engine stub binds per instance (BND-1). */
#define WASM_ENABLE_MULTI_MODULE 0

/* Bounds: the instruction budget, and the thread manager, so that wasm_runtime_terminate reaches the
   fast interpreter's suspend checks (ENG-4). */
#define WASM_ENABLE_INSTRUCTION_METERING 1
#define WASM_ENABLE_THREAD_MGR 1

/* Software bounds checks and no signal handlers in the embedder's process. */
#define WASM_DISABLE_HW_BOUND_CHECK 1
#define WASM_DISABLE_STACK_HW_BOUND_CHECK 1
#define WASM_DISABLE_WAKEUP_BLOCKING_OP 1
#define WASM_HAVE_MREMAP 0

/* No debugging, profiling or custom sections. */
#define WASM_ENABLE_DEBUG_INTERP 0
#define WASM_ENABLE_DUMP_CALL_STACK 0
#define WASM_ENABLE_PERF_PROFILING 0
#define WASM_ENABLE_MEMORY_PROFILING 0
#define WASM_ENABLE_LOAD_CUSTOM_SECTION 0
#define WASM_ENABLE_CUSTOM_NAME_SECTION 0
#define WASM_ENABLE_SPEC_TEST 0
#define WASM_ENABLE_WASI_TEST 0
#define WASM_ENABLE_SHARED_HEAP 0
#define WASM_ENABLE_COPY_CALL_STACK 0

#define BH_MALLOC wasm_runtime_malloc
#define BH_FREE wasm_runtime_free

/* As WAMR's CMake does: on MSVC, WAMR's own declarations then agree on their linkage. */
#define COMPILING_WASM_RUNTIME_API 1

/* The platform and the architecture. */
#if defined(__APPLE__)
#define BH_PLATFORM_DARWIN 1
#elif defined(__linux__)
#define BH_PLATFORM_LINUX 1
#elif defined(_WIN32)
#define BH_PLATFORM_WINDOWS 1
#define HAVE_STRUCT_TIMESPEC 1
#define _WINSOCK_DEPRECATED_NO_WARNINGS 1
#ifndef _CRT_SECURE_NO_WARNINGS
#define _CRT_SECURE_NO_WARNINGS 1
#endif
#else
#error "moonrockz/extism: the native engine supports macOS, Linux and Windows"
#endif

#if defined(__x86_64__) || defined(_M_X64)
#define BUILD_TARGET_X86_64 1
#define BUILD_TARGET "X86_64"
#elif defined(__aarch64__) || defined(_M_ARM64)
#define BUILD_TARGET_AARCH64 1
#define BUILD_TARGET "AARCH64"
#else
#error "moonrockz/extism: the native engine supports x86_64 and aarch64"
#endif

#endif
