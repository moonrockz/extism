///|
/// The import namespace of WASI preview 1.
pub let import_namespace : String = "wasi_snapshot_preview1"

///|
/// A core WASM type of a preview 1 function.
pub(all) enum WasiType {
  I32
  I64
} derive(Eq, Debug)

///|
pub extend WasiType with Eq::{equal, not_equal}

///|
pub extend WasiType with @debug.Debug::{to_repr}

///|
/// The 46 functions of `wasi_snapshot_preview1`, in the order of the witx.
pub(all) enum Function {
  ArgsGet
  ArgsSizesGet
  EnvironGet
  EnvironSizesGet
  ClockResGet
  ClockTimeGet
  FdAdvise
  FdAllocate
  FdClose
  FdDatasync
  FdFdstatGet
  FdFdstatSetFlags
  FdFdstatSetRights
  FdFilestatGet
  FdFilestatSetSize
  FdFilestatSetTimes
  FdPread
  FdPrestatGet
  FdPrestatDirName
  FdPwrite
  FdRead
  FdReaddir
  FdRenumber
  FdSeek
  FdSync
  FdTell
  FdWrite
  PathCreateDirectory
  PathFilestatGet
  PathFilestatSetTimes
  PathLink
  PathOpen
  PathReadlink
  PathRemoveDirectory
  PathRename
  PathSymlink
  PathUnlinkFile
  PollOneoff
  ProcExit
  ProcRaise
  SchedYield
  RandomGet
  SockAccept
  SockRecv
  SockSend
  SockShutdown
} derive(Eq, Debug)

///|
pub extend Function with Eq::{equal, not_equal}

///|
pub extend Function with @debug.Debug::{to_repr}

///|
/// Every preview 1 function, in the order of the witx.
pub fn Function::all() -> Array[Function] {
  [
    ArgsGet,
    ArgsSizesGet,
    EnvironGet,
    EnvironSizesGet,
    ClockResGet,
    ClockTimeGet,
    FdAdvise,
    FdAllocate,
    FdClose,
    FdDatasync,
    FdFdstatGet,
    FdFdstatSetFlags,
    FdFdstatSetRights,
    FdFilestatGet,
    FdFilestatSetSize,
    FdFilestatSetTimes,
    FdPread,
    FdPrestatGet,
    FdPrestatDirName,
    FdPwrite,
    FdRead,
    FdReaddir,
    FdRenumber,
    FdSeek,
    FdSync,
    FdTell,
    FdWrite,
    PathCreateDirectory,
    PathFilestatGet,
    PathFilestatSetTimes,
    PathLink,
    PathOpen,
    PathReadlink,
    PathRemoveDirectory,
    PathRename,
    PathSymlink,
    PathUnlinkFile,
    PollOneoff,
    ProcExit,
    ProcRaise,
    SchedYield,
    RandomGet,
    SockAccept,
    SockRecv,
    SockSend,
    SockShutdown,
  ]
}

///|
/// The import name of the function, for example `fd_write`.
pub fn Function::name(self : Function) -> String {
  match self {
    ArgsGet => "args_get"
    ArgsSizesGet => "args_sizes_get"
    EnvironGet => "environ_get"
    EnvironSizesGet => "environ_sizes_get"
    ClockResGet => "clock_res_get"
    ClockTimeGet => "clock_time_get"
    FdAdvise => "fd_advise"
    FdAllocate => "fd_allocate"
    FdClose => "fd_close"
    FdDatasync => "fd_datasync"
    FdFdstatGet => "fd_fdstat_get"
    FdFdstatSetFlags => "fd_fdstat_set_flags"
    FdFdstatSetRights => "fd_fdstat_set_rights"
    FdFilestatGet => "fd_filestat_get"
    FdFilestatSetSize => "fd_filestat_set_size"
    FdFilestatSetTimes => "fd_filestat_set_times"
    FdPread => "fd_pread"
    FdPrestatGet => "fd_prestat_get"
    FdPrestatDirName => "fd_prestat_dir_name"
    FdPwrite => "fd_pwrite"
    FdRead => "fd_read"
    FdReaddir => "fd_readdir"
    FdRenumber => "fd_renumber"
    FdSeek => "fd_seek"
    FdSync => "fd_sync"
    FdTell => "fd_tell"
    FdWrite => "fd_write"
    PathCreateDirectory => "path_create_directory"
    PathFilestatGet => "path_filestat_get"
    PathFilestatSetTimes => "path_filestat_set_times"
    PathLink => "path_link"
    PathOpen => "path_open"
    PathReadlink => "path_readlink"
    PathRemoveDirectory => "path_remove_directory"
    PathRename => "path_rename"
    PathSymlink => "path_symlink"
    PathUnlinkFile => "path_unlink_file"
    PollOneoff => "poll_oneoff"
    ProcExit => "proc_exit"
    ProcRaise => "proc_raise"
    SchedYield => "sched_yield"
    RandomGet => "random_get"
    SockAccept => "sock_accept"
    SockRecv => "sock_recv"
    SockSend => "sock_send"
    SockShutdown => "sock_shutdown"
  }
}

///|
/// The function with the import name `name`, or `None` for a name that preview 1 does not have.
pub fn Function::from_name(name : StringView) -> Function? {
  Function::all().iter().find_first(f => f.name() == name.to_owned())
}

///|
/// The core WASM parameter types of the function.
pub fn Function::params(self : Function) -> Array[WasiType] {
  match self {
    ArgsGet => [I32, I32]
    ArgsSizesGet => [I32, I32]
    EnvironGet => [I32, I32]
    EnvironSizesGet => [I32, I32]
    ClockResGet => [I32, I32]
    ClockTimeGet => [I32, I64, I32]
    FdAdvise => [I32, I64, I64, I32]
    FdAllocate => [I32, I64, I64]
    FdClose => [I32]
    FdDatasync => [I32]
    FdFdstatGet => [I32, I32]
    FdFdstatSetFlags => [I32, I32]
    FdFdstatSetRights => [I32, I64, I64]
    FdFilestatGet => [I32, I32]
    FdFilestatSetSize => [I32, I64]
    FdFilestatSetTimes => [I32, I64, I64, I32]
    FdPread => [I32, I32, I32, I64, I32]
    FdPrestatGet => [I32, I32]
    FdPrestatDirName => [I32, I32, I32]
    FdPwrite => [I32, I32, I32, I64, I32]
    FdRead => [I32, I32, I32, I32]
    FdReaddir => [I32, I32, I32, I64, I32]
    FdRenumber => [I32, I32]
    FdSeek => [I32, I64, I32, I32]
    FdSync => [I32]
    FdTell => [I32, I32]
    FdWrite => [I32, I32, I32, I32]
    PathCreateDirectory => [I32, I32, I32]
    PathFilestatGet => [I32, I32, I32, I32, I32]
    PathFilestatSetTimes => [I32, I32, I32, I32, I64, I64, I32]
    PathLink => [I32, I32, I32, I32, I32, I32, I32]
    PathOpen => [I32, I32, I32, I32, I32, I64, I64, I32, I32]
    PathReadlink => [I32, I32, I32, I32, I32, I32]
    PathRemoveDirectory => [I32, I32, I32]
    PathRename => [I32, I32, I32, I32, I32, I32]
    PathSymlink => [I32, I32, I32, I32, I32]
    PathUnlinkFile => [I32, I32, I32]
    PollOneoff => [I32, I32, I32, I32]
    ProcExit => [I32]
    ProcRaise => [I32]
    SchedYield => []
    RandomGet => [I32, I32]
    SockAccept => [I32, I32, I32]
    SockRecv => [I32, I32, I32, I32, I32, I32]
    SockSend => [I32, I32, I32, I32, I32]
    SockShutdown => [I32, I32]
  }
}

///|
/// The core WASM result types of the function: one `i32` errno, or none for `proc_exit`.
pub fn Function::results(self : Function) -> Array[WasiType] {
  match self {
    ProcExit => []
    _ => [I32]
  }
}
