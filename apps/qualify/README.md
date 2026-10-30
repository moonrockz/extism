# moonrockz/extism-qualify

The EXT-2 qualification gate (design GATE-1): it runs the Morphir Python extension on the native engine with
the embedded kernel, the raw-native kernel forwarders, a stub WASI and stubs for the `morphir_*` host functions,
and prints a receipt with the timings and the instructions of one compile. Run it with `mise run qualify:engine`,
which fetches the pinned module first. It is not published.
