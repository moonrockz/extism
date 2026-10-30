///|
/// What `config_get` gives.
pub(all) enum ConfigPolicy {
  /// A call fails with a denied error.
  Deny
  /// Every key gives handle 0.
  Empty
  /// The value of the key, or handle 0 for a key that is not in the map.
  Values(Map[String, String])
}

///|
/// What `var_get` and `var_set` do.
pub(all) enum VariablePolicy {
  /// A call of either fails with a denied error.
  Deny
  /// `var_get` gives handle 0 and `var_set` fails with a denied error.
  Empty
  /// Variables for the life of the plugin, with a limit on the total bytes of names and values.
  Session(ByteLimit)
}

///|
/// An Extism log level.
pub(all) enum LogLevel {
  Trace
  Debug
  Info
  Warn
  Error
} derive(Eq, Debug)

///|
pub extend LogLevel with Eq::{equal, not_equal}

///|
pub extend LogLevel with @debug.Debug::{to_repr}

///|
/// The number that `get_log_level` gives for the level: 0 for trace to 4 for error.
pub fn LogLevel::code(self : LogLevel) -> Int32 {
  match self {
    Trace => 0
    Debug => 1
    Info => 2
    Warn => 3
    Error => 4
  }
}

///|
/// What `get_log_level` gives when logging is off.
pub let logging_off : Int32 = 2147483647

///|
/// What the `log_*` functions do.
pub(all) enum LogPolicy {
  /// Every message is discarded, and `get_log_level` gives `logging_off`.
  Discard
  /// The sink gets each message at the level or above.
  Sink(LogLevel, (LogLevel, String) -> Unit)
}

///|
/// An HTTP request of a plugin, for the embedder's handler.
pub(all) struct HttpRequest {
  method_ : String
  url : String
  headers : Map[String, String]
  body : Bytes
}

///|
/// The embedder's answer to an HTTP request.
pub(all) struct HttpResponse {
  status : Int32
  headers : Map[String, String]
  body : Bytes
}

///|
/// What `http_request` does. The library never opens a connection.
pub(all) enum HttpPolicy {
  /// A call fails with a denied error that holds the method and the URL.
  Deny
  /// The handler answers each request.
  Handler((HttpRequest) -> HttpResponse raise @engine.HostError)
}

///|
/// The embedder's decision for each family of Extism host functions (PLG-2).
pub struct Policy {
  priv config : ConfigPolicy
  priv variables : VariablePolicy
  priv logging : LogPolicy
  priv http : HttpPolicy
}

///|
/// The default policy: configuration and variables answer empty, `var_set` is denied, log messages
/// are discarded and HTTP is denied.
pub fn Policy::default() -> Policy {
  { config: Empty, variables: Empty, logging: Discard, http: Deny, }
}

///|
pub fn Policy::config(self : Policy, config : ConfigPolicy) -> Policy {
  { ..self, config, }
}

///|
pub fn Policy::variables(self : Policy, variables : VariablePolicy) -> Policy {
  { ..self, variables, }
}

///|
pub fn Policy::logging(self : Policy, logging : LogPolicy) -> Policy {
  { ..self, logging, }
}

///|
pub fn Policy::http(self : Policy, http : HttpPolicy) -> Policy {
  { ..self, http, }
}

///|
/// The limits of a plugin: the memory ceilings of the plugin and of its kernel, the instruction
/// budget and the deadline of each call, and the default variable store limit.
pub struct Limits {
  priv plugin_memory : @engine.PageCount
  priv kernel_memory : @engine.PageCount
  priv budget : @engine.Budget?
  priv deadline : @engine.Deadline?
}

///|
/// The default limits: 4096 pages for the plugin and for the kernel, no budget and no deadline.
pub fn Limits::default() -> Limits {
  {
    plugin_memory: @engine.PageCount::default_ceiling(),
    kernel_memory: @engine.PageCount::default_ceiling(),
    budget: None,
    deadline: None,
  }
}

///|
pub fn Limits::plugin_memory(
  self : Limits,
  pages : @engine.PageCount,
) -> Limits {
  { ..self, plugin_memory: pages, }
}

///|
pub fn Limits::kernel_memory(
  self : Limits,
  pages : @engine.PageCount,
) -> Limits {
  { ..self, kernel_memory: pages, }
}

///|
pub fn Limits::budget(self : Limits, budget : @engine.Budget) -> Limits {
  { ..self, budget: Some(budget), }
}

///|
pub fn Limits::deadline(self : Limits, deadline : @engine.Deadline) -> Limits {
  { ..self, deadline: Some(deadline), }
}
