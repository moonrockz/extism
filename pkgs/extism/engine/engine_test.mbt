///|
fn compile(bytes : Bytes) -> @engine.Module raise @engine.EngineError {
  @engine.Engine::default().compile(bytes)
}

///|
fn pages(n : Int32) -> @engine.PageCount raise {
  @engine.PageCount::parse(n)
}

///|
fn kernel() -> @engine.Instance raise {
  compile(@kernel.bytes()).instantiate(
    @engine.Imports::new(),
    memory_ceiling=pages(64),
  )
}

///|
let i64_pair : @engine.Signature = @engine.Signature::new([I64, I64], [I64])

///|
test "Same module on both engines: two i64 values are added" {
  let instance = compile(@fixtures.add()).instantiate(@engine.Imports::new())
  assert_eq(instance.call("add", [I64(2), I64(40)]), [I64(42)])
  assert_eq(instance.call("add", [I64(-1L), I64(0x7fffffffffffffffL)]), [
    I64(0x7ffffffffffffffeL),
  ])
}

///|
test "Host function called by the guest" {
  let seen = []
  let imports = @engine.Imports::new().host("env", "add", i64_pair, (_, args) => {
    seen.push(args)
    guard args is [I64(a), I64(b)] else {
      raise @engine.HostError("bad arguments")
    }
    [I64(a + b)]
  })
  let instance = compile(@fixtures.host()).instantiate(imports)
  assert_eq(instance.call("call_add", [I64(5), I64(7)]), [I64(12)])
  assert_eq(seen, [[I64(5), I64(7)]])
}

///|
test "Wrong signature: the link error names the import and both signatures" {
  let imports = @engine.Imports::new().host(
    "env",
    "add",
    @engine.Signature::new([I32], [I32]),
    (_, args) => args,
  )
  let error = try compile(@fixtures.host()).instantiate(imports) catch {
    error => error
  } noraise {
    _ => fail("the instantiation must fail")
  }
  guard error is @engine.LinkError(name, detail) else {
    fail("not a link error")
  }
  assert_eq(name, "env.add")
  assert_true(detail.contains("(i64, i64) -> i64"))
  assert_true(detail.contains("(i32) -> i32"))
}

///|
test "a missing import is a link error that names it" {
  let error = try
    compile(@fixtures.host()).instantiate(@engine.Imports::new())
  catch {
    error => error
  } noraise {
    _ => fail("the instantiation must fail")
  }
  assert_true(error is @engine.LinkError("env.add", _))
}

///|
fn link_to(kernel : @engine.Instance) -> @engine.Imports raise {
  guard kernel.export_function("alloc") is Some(alloc) else { fail("no alloc") }
  @engine.Imports::new().function("extism:host/env", "alloc", alloc)
}

///|
test "Exports of one instance as imports of another" {
  let a = kernel()
  let b = compile(@fixtures.link()).instantiate(link_to(a))
  assert_eq(b.call("run", [I64(10)]), [I64(77)])
  // The allocation changed the kernel's root record (its bump position), not B's memory.
  guard a.memory() is Some(kernel_memory) && b.memory() is Some(b_memory) else {
    fail("no memory")
  }
  assert_eq(kernel_memory.read(9, 1), b"\x16")
  assert_eq(b_memory.read(0, 16), Bytes::make(16, b'\x00'))
}

///|
test "Two instances of one module reach their own linked instance" {
  let module_ = compile(@fixtures.link())
  let b1 = module_.instantiate(link_to(kernel()))
  let b2 = module_.instantiate(link_to(kernel()))
  assert_eq(b1.call("run", [I64(10)]), [I64(77)])
  assert_eq(b1.call("run", [I64(10)]), [I64(99)])
  assert_eq(b2.call("run", [I64(10)]), [I64(77)])
}

///|
test "Read past the end: a host function reads 8 bytes at 4 bytes before the end" {
  let outcome : Ref[String] = Ref("not called")
  let imports = @engine.Imports::new().host(
    "extism:host/env",
    "alloc",
    @engine.Signature::new([I64], [I64]),
    (caller, _) => {
      guard caller.memory() is Some(memory) else {
        raise @engine.HostError("no memory")
      }
      outcome.val = try memory.read(memory.size() - 4L, 8) catch {
        OutOfBounds(offset, length) => "out of bounds: \{offset} \{length}"
      } noraise {
        bytes => "read \{bytes.length()} bytes"
      }
      [I64(0)]
    },
  )
  let instance = compile(@fixtures.link()).instantiate(imports)
  instance.call("run", [I64(1)]) |> ignore
  assert_eq(outcome.val, "out of bounds: 65532 8")
}

///|
test "guest memory reads and writes inside the memory" {
  let instance = kernel()
  guard instance.memory() is Some(memory) else { fail("no memory") }
  memory.write(100000, b"hello")
  assert_eq(memory.read(100000, 5), b"hello")
  assert_true(
    try memory.write(memory.size() - 2L, b"abc") catch {
      _ => true
    } noraise {
      _ => false
    },
  )
}

///|
test "Module without a maximum: memory.grow past a ceiling of 32 pages gives -1" {
  let instance = compile(@fixtures.grow()).instantiate(
    @engine.Imports::new(),
    memory_ceiling=pages(32),
  )
  assert_eq(instance.call("grow", [I32(31)]), [I32(1)])
  assert_eq(instance.call("size", []), [I32(32)])
  assert_eq(instance.call("grow", [I32(1)]), [I32(-1)])
  assert_eq(instance.call("size", []), [I32(32)])
}

///|
test "Refused grow, then a trap: the call fails with a memory limit error" {
  let instance = compile(@fixtures.grow()).instantiate(
    @engine.Imports::new(),
    memory_ceiling=pages(32),
  )
  let error = try instance.call("grow_then_trap", [I32(40)]) catch {
    error => error
  } noraise {
    _ => fail("the call must fail")
  }
  assert_true(error is MemoryLimit)
}

///|
test "Ceiling below the initial pages: the error holds both page counts" {
  let ceiling = pages(8)
  let module_ = compile(@fixtures.big())
  let error = try
    module_.instantiate(@engine.Imports::new(), memory_ceiling=ceiling)
  catch {
    error => error
  } noraise {
    _ => fail("the instantiation must fail")
  }
  assert_true(error is CeilingBelowInitial(8, 16))
}

///|
test "Unreachable: the trap kind is unreachable and the instance takes no more calls" {
  let instance = compile(@fixtures.traps()).instantiate(@engine.Imports::new())
  let error = try instance.call("boom", []) catch {
    error => error
  } noraise {
    _ => fail("the call must trap")
  }
  assert_true(error is Trap(Unreachable))
  assert_false(instance.is_usable())
  let again = try instance.call("boom", []) catch {
    error => error
  } noraise {
    _ => fail("the call must fail")
  }
  assert_true(again is Unusable)
}

///|
fn trap_of(
  name : String,
  args : Array[@engine.Value],
) -> @engine.CallError raise {
  let instance = compile(@fixtures.traps()).instantiate(@engine.Imports::new())
  try instance.call(name, args) catch {
    error => error
  } noraise {
    _ => fail("the call must trap")
  }
}

///|
test "traps have their kind" {
  assert_true(trap_of("divide", [I32(0)]) is Trap(DivideByZero))
  assert_true(trap_of("load", [I32(65535)]) is Trap(MemoryOutOfBounds))
}

///|
test "a host function that fails ends the call with its error" {
  let imports = @engine.Imports::new().host("env", "add", i64_pair, (_, _) => {
    raise @engine.HostError("not found")
  })
  let instance = compile(@fixtures.host()).instantiate(imports)
  let error = try instance.call("call_add", [I64(1), I64(2)]) catch {
    error => error
  } noraise {
    _ => fail("the call must fail")
  }
  assert_true(error is Host(HostError("not found")))
}

///|
test "an unknown export or wrong arguments leave the instance usable" {
  let instance = compile(@fixtures.add()).instantiate(@engine.Imports::new())
  let unknown = try instance.call("sub", []) catch {
    error => error
  } noraise {
    _ => fail("the call must fail")
  }
  assert_true(unknown is UnknownExport("sub"))
  let mismatch = try instance.call("add", [I32(1)]) catch {
    error => error
  } noraise {
    _ => fail("the call must fail")
  }
  assert_true(mismatch is ArgumentMismatch("add", _))
  assert_true(instance.is_usable())
  assert_true(instance.has_function("add"))
  assert_false(instance.has_function("sub"))
}

///|
test "imports and exports of a module" {
  let module_ = compile(@fixtures.host())
  assert_eq(module_.imports(), [
    { module_: "env", name: "add", kind: Function(Some(i64_pair)), },
  ])
  assert_eq(module_.exports(), [
    { name: "call_add", kind: Function(Some(i64_pair)), },
  ])
}

///|
test "bytes that are not a module are invalid" {
  assert_true(
    try compile(b"\x00asm\x01\x00\x00\x00\x01") catch {
      Invalid(_) => true
      _ => false
    } noraise {
      _ => false
    },
  )
}

///|
test "Budget range: 2147483647 is accepted and 2147483648 is refused" {
  assert_eq(@engine.Budget::parse(2147483647L).instructions(), 2147483647)
  assert_eq(@engine.Budget::parse(1L).instructions(), 1)
  let refused = (n : Int64) => {
    try @engine.Budget::parse(n) catch {
      LimitError(name, value, rule) =>
        name == "instruction budget" && value == n && rule != ""
    } noraise {
      _ => false
    }
  }
  assert_true(refused(2147483648L))
  assert_true(refused(0L))
}

///|
test "page counts are from 1 to 65536" {
  assert_eq(@engine.PageCount::parse(1).pages(), 1)
  assert_eq(@engine.PageCount::parse(65536).pages(), 65536)
  let refused = (n : Int32) => {
    try @engine.PageCount::parse(n) catch {
      _ => true
    } noraise {
      _ => false
    }
  }
  assert_true(refused(0))
  assert_true(refused(65537))
  assert_eq(@engine.PageCount::default_ceiling().pages(), 4096)
}

///|
test "deadlines are 1 millisecond or more" {
  assert_eq(@engine.Deadline::parse(1).milliseconds(), 1)
  assert_true(
    try @engine.Deadline::parse(0) catch {
      _ => true
    } noraise {
      _ => false
    },
  )
}

///|
test "Feature scan through the engine package" {
  assert_eq(@engine.Feature::scan(@fixtures.simd()), [Simd])
  assert_eq(@engine.Feature::Simd.name(), "simd")
  assert_eq(@engine.Feature::ExceptionHandling.name(), "exception-handling")
}

///|
test "signatures print as WAT writes them" {
  assert_eq(i64_pair.to_string(), "(i64, i64) -> i64")
  assert_eq(@engine.Signature::new([], []).to_string(), "() -> ()")
}
