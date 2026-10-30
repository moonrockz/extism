# Spec Delta

## Purpose

Defines the WASI preview 1 import set that the library gives to sandboxed plugins: which functions are linked,
the answer of each, and what the embedder supplies, so that a plugin built with a WASI toolchain starts and runs
with no ambient authority.

## ADDED Requirements

### Requirement: Every preview 1 function is linked
When the embedder enables the WASI sandbox, the library SHALL link every function of `wasi_snapshot_preview1`
with its preview 1 signature, so that no WASI import of a plugin is unlinked.

#### Scenario: Plugin that imports an unusual function
- **WHEN** a plugin imports `wasi_snapshot_preview1.path_symlink` and the sandbox is enabled
- **THEN** the plugin loads, and a call of `path_symlink` returns an error code

#### Scenario: Sandbox not enabled
- **WHEN** a plugin imports `wasi_snapshot_preview1.fd_write` and the embedder did not enable the sandbox
- **THEN** the load fails with an unlinked import error that names `wasi_snapshot_preview1.fd_write`

### Requirement: Empty arguments and environment
`args_sizes_get` and `environ_sizes_get` SHALL report zero entries and zero bytes, and `args_get` and
`environ_get` SHALL write nothing and succeed.

#### Scenario: Program reads its arguments
- **WHEN** a WASI program reads its arguments and its environment at start
- **THEN** it gets an empty list for each, and the call returns success

### Requirement: Empty stdin
`fd_read` on fd 0 SHALL succeed and read 0 bytes.

#### Scenario: Program reads stdin
- **WHEN** a plugin reads fd 0
- **THEN** it reads 0 bytes, which is end of file

### Requirement: Stdout and stderr to embedder sinks
`fd_write` on fd 1 and fd 2 SHALL give the bytes to the stdout and stderr sinks that the embedder supplies, in
order, one iovec at a time, and report the bytes as written. Without a sink, the bytes SHALL be discarded and
reported as written.

#### Scenario: Plugin prints
- **WHEN** a plugin writes `hello` to fd 1 and `oops` to fd 2
- **THEN** the stdout sink gets `hello`, the stderr sink gets `oops`, and each `fd_write` reports all bytes written

### Requirement: Bounded writes
Each sink SHALL have a bound, from 1 byte to 16 MiB and 1 MiB by default. One `fd_write` SHALL give a sink at most
its bound: it writes the first bytes up to the bound and reports that count, as a POSIX `write` that writes part
of its bytes. The bound applies to each call, and the embedder's sink bounds the total.

#### Scenario: Write over the bound
- **WHEN** a plugin writes `hel` and `lo` in one `fd_write` to a sink with a bound of 4 bytes
- **THEN** the sink gets `hel` and then `l`, and the call reports 4 bytes written

#### Scenario: Writes in a loop
- **WHEN** a plugin writes 64 KiB in a loop that does not end, to a sink with a bound of 4 KiB, with a deadline,
  on native
- **THEN** each sink call gets at most 4 KiB, and the call ends with `Interrupted`

### Requirement: Checked write arguments
An `fd_write` with more than 1024 iovecs SHALL return `EINVAL`. An `fd_write` with an iovec array, a buffer or a
result address outside guest memory SHALL return `EFAULT`. In both cases no byte SHALL go to the sink.

#### Scenario: Too many iovecs
- **WHEN** a plugin calls `fd_write` with 1025 iovecs
- **THEN** the call returns `EINVAL` and the sink gets nothing

#### Scenario: Buffer outside memory
- **WHEN** the second iovec of an `fd_write` ends past the end of guest memory
- **THEN** the call returns `EFAULT` and the sink gets nothing, also not the first iovec

### Requirement: Clock and random sources from the embedder
`clock_time_get` and `clock_res_get` SHALL answer from the clock source that the embedder supplies, and
`random_get` SHALL fill the buffer from the random source that the embedder supplies. Without a source, these
functions SHALL return `ENOTCAPABLE`.

#### Scenario: Deterministic clock
- **WHEN** the embedder supplies a clock that always gives 42 ns and the plugin calls `clock_time_get`
- **THEN** the plugin reads 42

#### Scenario: No random source
- **WHEN** the embedder supplies no random source and the plugin calls `random_get`
- **THEN** the call returns `ENOTCAPABLE` and the buffer is not changed

#### Scenario: Random range outside memory
- **WHEN** a plugin calls `random_get` with a buffer that ends past guest memory, or a length of 2^31 or more
- **THEN** the call returns `EFAULT`, and the embedder's random source is not called

### Requirement: Standard stream status
`fd_fdstat_get` and `fd_filestat_get` on fd 0, 1 and 2 SHALL succeed, because wasi-libc and CPython check them at
start-up. `fd_fdstat_get` SHALL give a character device with no flags, the `fd_read` right for fd 0, the
`fd_write` right for fd 1 and fd 2, and no inheriting rights. `fd_filestat_get` SHALL give a character device with
device 0, inode 0, link count 0, size 0 and all times 0.

#### Scenario: Start-up checks of stdout
- **WHEN** a plugin calls `fd_fdstat_get` on fd 1
- **THEN** the call succeeds and the plugin reads a character device with the `fd_write` right

### Requirement: No preopens and error codes for all other functions
The sandbox SHALL have no preopened directories. A function with an fd argument other than 0, 1 and 2 SHALL return
`EBADF`. Every other function and operation that this spec does not give an answer SHALL return `ENOTCAPABLE`.
No function SHALL reach a file, socket, process or the host environment.

#### Scenario: Preopen scan
- **WHEN** a WASI libc start-up calls `fd_prestat_get` on fd 3
- **THEN** the call returns `EBADF` and the plugin sees no preopened directories

#### Scenario: Open a file
- **WHEN** a plugin calls `path_open` with fd 3
- **THEN** the call returns `EBADF` and no file is opened

#### Scenario: Write to stdin
- **WHEN** a plugin calls `fd_write` on fd 0
- **THEN** the call returns `ENOTCAPABLE`

### Requirement: Process exit
`proc_exit` SHALL stop the current call and SHALL give its exit code to the caller as a typed result. It SHALL NOT
stop the embedder's process. In a plugin call, `proc_exit(0)` with no kernel error set SHALL be a successful call
that returns the output set so far; any other code SHALL fail the call with an exit error that holds the code.

#### Scenario: Plugin exits with code 3
- **WHEN** a plugin calls `proc_exit(3)` during a call
- **THEN** the call ends with an exit result that holds 3, and the embedder's process continues

#### Scenario: Plugin exits with code 0
- **WHEN** a plugin sets its output to `done` and calls `proc_exit(0)` during a call
- **THEN** the call succeeds and returns `done`

### Requirement: One implementation for every engine
The sandbox SHALL work only through the guest memory access of the engine layer, so that native and js give the
same answers to the same calls.

#### Scenario: Same answers on native and js
- **WHEN** the same WASI fixture plugin runs on the native and the js engine with the same sources and sinks
- **THEN** the sinks get the same bytes and the call gives the same result
