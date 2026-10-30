//! Zig tests of the kernel on a native buffer that acts as linear memory. The expected values are the
//! results of the upstream Rust kernel for the same calls.

const std = @import("std");
const core = @import("core.zig");
const testing = std.testing;

const max_pages = 64;

/// A linear memory of 16 initial pages, as the kernel module declares, that grows up to `ceiling` pages.
const TestMemory = struct {
    var buffer: [max_pages * core.page_size]u8 align(8) = undefined;
    var pages: u32 = 16;
    var ceiling: u32 = max_pages;

    fn init(ceiling_pages: u32) void {
        @memset(&buffer, 0);
        pages = 16;
        ceiling = ceiling_pages;
    }

    pub fn bytes() [*]allowzero u8 {
        return &buffer;
    }

    pub fn size() u64 {
        return @as(u64, pages) * core.page_size;
    }

    pub fn grow(count: u32) bool {
        if (count > ceiling - pages) return false;
        pages += count;
        return true;
    }
};

const K = core.Kernel(TestMemory);

fn fresh() void {
    TestMemory.init(max_pages);
}

fn put(bytes: []const u8) u64 {
    const handle = K.alloc(bytes.len);
    for (bytes, 0..) |byte, i| K.storeU8(handle + i, byte);
    return handle;
}

fn get(handle: u64, out: []u8) []u8 {
    const len = K.length(handle);
    for (0..len) |i| out[i] = K.loadU8(handle + i);
    return out[0..len];
}

test "the first allocation follows the root record and a block header" {
    fresh();
    try testing.expectEqual(@as(u64, 77), K.alloc(10));
    try testing.expectEqual(@as(u64, 99), K.alloc(5));
    try testing.expectEqual(@as(u64, 10), K.length(77));
    try testing.expectEqual(@as(u64, 5), K.length(99));
}

test "alloc of zero bytes gives no handle" {
    fresh();
    try testing.expectEqual(@as(u64, 0), K.alloc(0));
}

test "the tracked length starts at one page less the root record" {
    fresh();
    try testing.expectEqual(@as(u64, 65536 - 64), K.memoryBytes());
}

test "an allocation past the tracked length grows the memory by whole pages" {
    fresh();
    const handle = K.alloc(70000);
    try testing.expectEqual(@as(u64, 77), handle);
    try testing.expectEqual(@as(u64, 65536 - 64 + 65536), K.memoryBytes());
    try testing.expectEqual(@as(u32, 17), TestMemory.pages);
    try testing.expectEqual(@as(u64, 70000), K.length(handle));
}

test "length of a freed, an unknown and a zero handle is zero" {
    fresh();
    const a = K.alloc(8);
    const b = K.alloc(8);
    K.free(a);
    try testing.expectEqual(@as(u64, 0), K.length(a));
    try testing.expectEqual(@as(u64, 8), K.length(b));
    try testing.expectEqual(@as(u64, 0), K.length(a + 1));
    try testing.expectEqual(@as(u64, 0), K.length(0));
    try testing.expectEqual(@as(u64, 0), K.length(1 << 40));
}

test "length_unsafe reads the header of an active block only" {
    fresh();
    const a = K.alloc(8);
    try testing.expectEqual(@as(u64, 8), K.lengthUnsafe(a));
    K.free(a);
    try testing.expectEqual(@as(u64, 0), K.lengthUnsafe(a));
    try testing.expectEqual(@as(u64, 0), K.lengthUnsafe(0));
    try testing.expectEqual(@as(u64, 0), K.lengthUnsafe(TestMemory.size() + 1));
}

test "a freed block is reused before the memory grows" {
    fresh();
    TestMemory.init(16);
    const a = K.alloc(30000);
    const b = K.alloc(30000);
    try testing.expect(a != 0 and b != 0);
    K.free(a);
    // The next allocation does not fit in the tracked length and is not larger than the position,
    // so the freed block is reused without growing the memory.
    const c = K.alloc(29900);
    try testing.expectEqual(a, c);
    try testing.expectEqual(@as(u64, 29900), K.length(c));
    try testing.expectEqual(@as(u32, 16), TestMemory.pages);
}

test "a free block much larger than the allocation is split, and the end part is used" {
    fresh();
    const a = K.alloc(60000);
    K.free(a);
    const b = K.alloc(10000);
    // The split block is at the end of the freed block: its data ends where the freed data ended.
    try testing.expectEqual(a + 60000 - 10000, b);
    try testing.expectEqual(@as(u64, 10000), K.length(b));
    try testing.expectEqual(@as(u64, 0), K.length(a));
}

test "alloc returns zero at the memory ceiling and keeps earlier bytes" {
    fresh();
    TestMemory.init(17);
    const kept = put("kept");
    try testing.expectEqual(@as(u64, 0), K.alloc(20 * core.page_size));
    var out: [16]u8 = undefined;
    try testing.expectEqualStrings("kept", get(kept, &out));
}

test "loads and stores inside the root record or past the memory do nothing" {
    fresh();
    const before = K.alloc(4);
    K.storeU8(1, 0);
    K.storeU64(9, 12345);
    try testing.expectEqual(@as(u64, 0), K.loadU8(1));
    try testing.expectEqual(@as(u64, 0), K.loadU64(9));
    try testing.expectEqual(before + 4 + core.block_header_size, K.alloc(4));
    const end = TestMemory.size();
    try testing.expectEqual(@as(u64, 0), K.loadU64(end - 4));
    try testing.expectEqual(@as(u64, 0), K.loadU64(end - 7));
    try testing.expectEqual(@as(u8, 0), K.loadU8(end));
    K.storeU64(end - 4, 1);
    K.storeU8(end, 1);
    try testing.expectEqual(@as(u64, 0), K.loadU64(1 << 63));
}

test "store and load round-trip in little endian" {
    fresh();
    const h = K.alloc(16);
    K.storeU64(h, 0x0102030405060708);
    try testing.expectEqual(@as(u8, 0x08), K.loadU8(h));
    try testing.expectEqual(@as(u64, 0x0102030405060708), K.loadU64(h));
    K.storeU8(h + 8, 0xff);
    try testing.expectEqual(@as(u8, 0xff), K.loadU8(h + 8));
}

test "input reads stop at the input length" {
    fresh();
    const h = put("abc");
    K.inputSet(h, 3);
    try testing.expectEqual(@as(u64, 3), K.inputLength());
    try testing.expectEqual(h, K.inputOffset());
    try testing.expectEqual(@as(u8, 'c'), K.inputLoadU8(2));
    try testing.expectEqual(@as(u8, 0), K.inputLoadU8(3));
    try testing.expectEqual(@as(u64, 0), K.inputLoadU64(0));
}

test "input_load_u64 reads eight bytes of the input" {
    fresh();
    const h = put("abcdefghij");
    K.inputSet(h, 10);
    try testing.expectEqual(std.mem.readInt(u64, "abcdefgh", .little), K.inputLoadU64(0));
    try testing.expectEqual(std.mem.readInt(u64, "cdefghij", .little), K.inputLoadU64(2));
    try testing.expectEqual(@as(u64, 0), K.inputLoadU64(3));
}

test "input_set and output_set outside the blocks change nothing" {
    fresh();
    const h = put("xyz");
    K.inputSet(1, 3);
    try testing.expectEqual(@as(u64, 0), K.inputLength());
    K.outputSet(h, 1 << 40);
    try testing.expectEqual(@as(u64, 0), K.outputLength());
    K.outputSet(h, 3);
    try testing.expectEqual(h, K.outputOffset());
    try testing.expectEqual(@as(u64, 3), K.outputLength());
}

test "freeing the input sets the input length to zero" {
    fresh();
    const h = put("abc");
    K.inputSet(h, 3);
    K.free(h);
    try testing.expectEqual(@as(u64, 0), K.inputLength());
    try testing.expectEqual(h, K.inputOffset());
}

test "error_set takes a handle in the blocks or zero" {
    fresh();
    const h = put("bad input");
    K.errorSet(h);
    try testing.expectEqual(h, K.errorGet());
    K.errorSet(1 << 40);
    try testing.expectEqual(h, K.errorGet());
    K.errorSet(0);
    try testing.expectEqual(@as(u64, 0), K.errorGet());
}

test "reset clears the blocks, the input, the output and the error" {
    fresh();
    const h = put("abc");
    K.inputSet(h, 3);
    K.outputSet(h, 3);
    K.errorSet(h);
    K.reset();
    try testing.expectEqual(@as(u64, 0), K.inputLength());
    try testing.expectEqual(@as(u64, 0), K.inputOffset());
    try testing.expectEqual(@as(u64, 0), K.outputLength());
    try testing.expectEqual(@as(u64, 0), K.outputOffset());
    try testing.expectEqual(@as(u64, 0), K.errorGet());
    try testing.expectEqual(@as(u64, 0), K.length(h));
    try testing.expectEqual(@as(u8, 0), K.loadU8(h));
    try testing.expectEqual(h, K.alloc(3));
}

test "reset keeps the tracked length" {
    fresh();
    _ = K.alloc(70000);
    const grown = K.memoryBytes();
    K.reset();
    try testing.expectEqual(grown, K.memoryBytes());
}

test "the bounds rule is the upstream one: the last byte at 64 or above" {
    fresh();
    _ = K.alloc(1);
    // Offset 64 is the last byte of the root record (the high byte of the output length), as upstream exposes it.
    K.storeU8(64, 7);
    try testing.expectEqual(@as(u8, 7), K.loadU8(64));
    K.storeU8(64, 0);
    try testing.expectEqual(@as(u8, 0), K.loadU8(63));
    // A u64 at 57 ends at 64, so it runs; at 56 it ends at 63 and does not.
    try testing.expectEqual(@as(u64, 0), K.loadU64(56));
    K.storeU64(56, 0xffff);
    try testing.expectEqual(@as(u64, 0), K.outputLength());
}

test "an access that ends past the memory is refused where upstream traps" {
    fresh();
    const end = TestMemory.size();
    try testing.expectEqual(@as(u8, 0), K.loadU8(end));
    try testing.expectEqual(@as(u64, 0), K.loadU64(end - 7));
    K.storeU8(end - 1, 9);
    try testing.expectEqual(@as(u8, 9), K.loadU8(end - 1));
}
