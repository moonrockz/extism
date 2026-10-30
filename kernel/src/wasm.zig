//! The WASM exports of the kernel: the 20 upstream kernel functions with their upstream names and
//! signatures, over the module's own linear memory. Build with `zig build` (see build.zig).

const core = @import("core.zig");

const Memory = struct {
    pub fn bytes() [*]allowzero u8 {
        return @ptrFromInt(0);
    }

    pub fn size() u64 {
        return @as(u64, @wasmMemorySize(0)) * core.page_size;
    }

    pub fn grow(pages: u32) bool {
        return @wasmMemoryGrow(0, pages) != -1;
    }
};

const K = core.Kernel(Memory);

export fn alloc(n: u64) u64 {
    return K.alloc(n);
}
export fn free(p: u64) void {
    K.free(p);
}
export fn length(p: u64) u64 {
    return K.length(p);
}
export fn length_unsafe(p: u64) u64 {
    return K.lengthUnsafe(p);
}
export fn load_u8(p: u64) u8 {
    return K.loadU8(p);
}
export fn load_u64(p: u64) u64 {
    return K.loadU64(p);
}
export fn input_load_u8(offset: u64) u8 {
    return K.inputLoadU8(offset);
}
export fn input_load_u64(offset: u64) u64 {
    return K.inputLoadU64(offset);
}
export fn store_u8(p: u64, x: u8) void {
    K.storeU8(p, x);
}
export fn store_u64(p: u64, x: u64) void {
    K.storeU64(p, x);
}
export fn input_set(h: u64, len: u64) void {
    K.inputSet(h, len);
}
export fn output_set(h: u64, len: u64) void {
    K.outputSet(h, len);
}
export fn input_length() u64 {
    return K.inputLength();
}
export fn input_offset() u64 {
    return K.inputOffset();
}
export fn output_length() u64 {
    return K.outputLength();
}
export fn output_offset() u64 {
    return K.outputOffset();
}
export fn reset() void {
    K.reset();
}
export fn error_set(h: u64) void {
    K.errorSet(h);
}
export fn error_get() u64 {
    return K.errorGet();
}
export fn memory_bytes() u64 {
    return K.memoryBytes();
}
