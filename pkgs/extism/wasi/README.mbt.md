# moonrockz/extism/wasi

A WASI preview 1 sandbox for Extism plugins (design WASI-1). It links every function of
`wasi_snapshot_preview1` and gives no ambient authority: no preopens, empty arguments, environment and
stdin, clocks and random bytes from sources that the embedder gives, and stdout and stderr to sinks that the
embedder gives. It works on any `GuestMemory`, so the native and the js engine give the same answers.

The bound of a sink applies to each `fd_write`. A guest that writes in a loop makes many calls, so the sink
bounds the total itself, for example with a tail of the last bytes; the deadline of the call ends the loop.

| Functions | Answer |
| --- | --- |
| `args_get`, `args_sizes_get`, `environ_get`, `environ_sizes_get` | Zero entries; success |
| `fd_read` | fd 0 reads 0 bytes (end of file); fd 1 and 2: `ENOTCAPABLE` |
| `fd_write` | fd 1 and 2: the embedder's sinks, one iovec at a time, at most the sink's `SinkBound` per call (1 MiB by default; the first bytes are written and reported); discarded without a sink. More than 1024 iovecs: `EINVAL`; a range outside memory: `EFAULT`, before a byte goes to the sink. fd 0: `ENOTCAPABLE` |
| `clock_res_get`, `clock_time_get`, `random_get` | The embedder's sources; `ENOTCAPABLE` (76) without one. `random_get` checks its range before it calls the source |
| `fd_fdstat_get`, `fd_filestat_get` | A character device for fds 0, 1 and 2 |
| `proc_exit` | Ends the call with the exit code |
| Any function with an fd argument other than 0, 1 and 2 | `EBADF` (8) |
| Every other function | `ENOTCAPABLE` (76) |

The test below checks that this table is the function table of the package:

```moonbit check
///|
test "the README table is the function table" {
  let table : Array[(Array[String], @wasi.Answer)] = [
    (
      ["args_get", "args_sizes_get", "environ_get", "environ_sizes_get"],
      NoEntries,
    ),
    (["fd_read"], EndOfFile),
    (["fd_write"], Sinks),
    (["clock_res_get", "clock_time_get", "random_get"], Sources),
    (["fd_fdstat_get", "fd_filestat_get"], StreamStatus),
    (["proc_exit"], Ends),
  ]
  for function in @wasi.Function::all() {
    let documented = table
      .iter()
      .find_first(row => row.0.contains(function.name()))
      .map(row => row.1)
      .unwrap_or(NotCapable)
    assert_eq(function.answer(), documented)
  }
}
```

A sandbox with a clock and a stdout sink:

```moonbit check
///|
test "a sandbox with a clock and a sink" {
  let printed = []
  let sandbox = @wasi.Sandbox::new()
    .clock({ time: _ => 42UL, resolution: _ => 1UL, })
    .stdout(bytes => printed.push(bytes.to_owned()))
  assert_eq(@wasi.Function::all().length(), 46)
  ignore(sandbox)
  assert_eq(printed.length(), 0)
}
```
