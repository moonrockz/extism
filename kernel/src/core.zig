//! The Extism kernel: the allocator, handles, input, output and errors that serve the `extism:host/env`
//! memory functions of a plugin.
//!
//! The memory layout and the results are the ones of the upstream Rust kernel
//! (`extism/extism`, `kernel/src/lib.rs`, built with its default `bounds-checking` feature):
//!
//!   | 0 | Root (64 bytes, at offset 1) | Block header (12) + data | Block header (12) + data | ...
//!
//! A handle is the offset of the data of a block. Zero is no block. The arithmetic wraps, as the upstream
//! release build does. Where an upstream access would trap because it is outside the linear memory, this
//! kernel returns 0 or changes nothing; a kernel call never reads or writes outside its memory.
//!
//! The functions are generic over the linear memory, so that the Zig tests run them on a native buffer and
//! `wasm.zig` runs them on the WASM memory.

const std = @import("std");

pub const page_size: u64 = 65536;

/// The root record starts at offset 1, as upstream.
pub const root_offset: u64 = 1;
pub const root_size: u64 = 64;

/// The first block header, directly after the root record.
pub const blocks_offset: u64 = root_offset + root_size;

/// A block header: status (u8), padding, size (u32) and used length (u32).
pub const block_header_size: u64 = 12;

/// The bytes after the root record that the first initialization clears, as upstream: 12 headers.
pub const root_clear_size: u64 = block_header_size * block_header_size;

/// Free blocks with at least this many bytes more than an allocation are split.
const split_threshold: u32 = 128;

const Status = enum(u8) { unused = 0, active = 1, free = 2 };

/// No block. A block header is never at offset 0, which is outside the blocks. The block functions return
/// it in place of an optional, so that no result goes through a stack in linear memory.
const none: u64 = 0;

/// A block walk that reaches a header outside the memory, where upstream traps.
const walk_failed: u64 = std.math.maxInt(u64);

// Offsets of the root record fields (repr(C) of the upstream `MemoryRoot`, placed at offset 1).
const initialized_at = root_offset + 0;
const position_at = root_offset + 8;
const length_at = root_offset + 16;
const error_at = root_offset + 24;
const input_offset_at = root_offset + 32;
const input_length_at = root_offset + 40;
const output_offset_at = root_offset + 48;
const output_length_at = root_offset + 56;

// Offsets in a block header.
const status_in_block = 0;
const size_in_block = 4;
const used_in_block = 8;

/// The kernel over a linear memory. `Memory` gives:
///
/// - `fn bytes() [*]allowzero u8`: the start of the linear memory,
/// - `fn size() u64`: the size of the linear memory in bytes,
/// - `fn grow(pages: u32) bool`: grows the memory by `pages` pages, false when it cannot.
pub fn Kernel(comptime Memory: type) type {
    return struct {
        fn inMemory(at: u64, count: u64) bool {
            const end = Memory.size();
            return at <= end and count <= end - at;
        }

        fn readU8(at: u64) u8 {
            return Memory.bytes()[@intCast(at)];
        }

        fn writeU8(at: u64, value: u8) void {
            Memory.bytes()[@intCast(at)] = value;
        }

        fn readLittle(comptime T: type, at: u64) T {
            const start: usize = @intCast(at);
            var value: T = 0;
            inline for (0..@sizeOf(T)) |i| value |= @as(T, Memory.bytes()[start + i]) << (8 * i);
            return value;
        }

        fn writeLittle(comptime T: type, at: u64, value: T) void {
            const start: usize = @intCast(at);
            inline for (0..@sizeOf(T)) |i| Memory.bytes()[start + i] = @truncate(value >> (8 * i));
        }

        fn readU32(at: u64) u32 {
            return readLittle(u32, at);
        }

        fn writeU32(at: u64, value: u32) void {
            writeLittle(u32, at, value);
        }

        fn readU64(at: u64) u64 {
            return readLittle(u64, at);
        }

        fn writeU64(at: u64, value: u64) void {
            writeLittle(u64, at, value);
        }

        /// Initializes the root record on the first kernel call (upstream `MemoryRoot::new`).
        fn root() void {
            if (Memory.size() == 0 and !Memory.grow(1)) unreachable;
            if (readU8(initialized_at) != 0) return;
            writeU8(initialized_at, 1);
            writeU64(input_offset_at, 0);
            writeU64(input_length_at, 0);
            writeU64(output_offset_at, 0);
            writeU64(output_length_at, 0);
            writeU64(error_at, 0);
            writeU64(length_at, page_size - root_size);
            writeU64(position_at, 0);
            // Upstream calls `write_bytes` on a `MemoryBlock` pointer with the count
            // `size_of::<MemoryBlock>()`, so it clears that many block headers, not one.
            @memset(Memory.bytes()[@intCast(blocks_offset)..][0..@intCast(root_clear_size)], 0);
        }

        /// Upstream `pointer_in_bounds`: inside the blocks that the allocator tracks.
        fn inBlocks(p: u64) bool {
            return p >= blocks_offset and p < blocks_offset +% readU64(length_at);
        }

        /// Upstream `pointer_in_bounds_fast`: above the root record and not past the memory size.
        fn inBoundsFast(p: u64) bool {
            return p >= root_size and p <= Memory.size();
        }

        /// The upstream bounds rule for a load or store of `count` bytes at `p`: the last byte is at offset 64 or
        /// above, and the access ends inside the memory. Upstream checks the last byte against the memory size and
        /// traps when the access ends past it; this kernel refuses that access instead.
        fn accessible(p: u64, count: u64) bool {
            return inMemory(p, count) and p + count - 1 >= root_size;
        }

        fn numPages(count: u64) u64 {
            return count / page_size + @intFromBool(count % page_size != 0);
        }

        /// An address as upstream computes it: a wasm32 pointer, so the sum wraps at 2^32.
        fn address(value: u64) u64 {
            return @as(u32, @truncate(value));
        }

        fn nextBlock(block: u64) u64 {
            return address(block +% block_header_size +% readU32(block + size_in_block));
        }

        /// A free or unused block for `count` bytes, `none`, or `walk_failed` where upstream traps: the walk
        /// reads a status or a size outside the memory, or the block that it gives has a header that ends
        /// outside the memory. Upstream reads the status, then the size, of each block, and nothing more.
        fn findFreeBlock(count: u64, position: u64) u64 {
            const wanted: u32 = @truncate(count);
            var block = blocks_offset;
            while (block < blocks_offset +% position) : (block = nextBlock(block)) {
                if (!inMemory(block + status_in_block, 1)) return walk_failed;
                const status = readU8(block + status_in_block);
                if (status == @intFromEnum(Status.unused)) {
                    // The caller writes the used length and the status of the block.
                    if (!inMemory(block, block_header_size)) return walk_failed;
                    return block;
                }
                if (!inMemory(block + size_in_block, 4)) return walk_failed;
                const size = readU32(block + size_in_block);
                if (status == @intFromEnum(Status.free) and size >= wanted) {
                    if (!inMemory(block, block_header_size)) return walk_failed;
                    if (size - wanted >= split_threshold) {
                        const kept = size -% (wanted +% @as(u32, block_header_size));
                        const split = address(block +% block_header_size +% kept);
                        // Upstream traps at the write of the split header; nothing changes here.
                        if (!inMemory(split, block_header_size)) return walk_failed;
                        writeU32(block + size_in_block, kept);
                        writeU32(block + used_in_block, 0);
                        writeU32(split + size_in_block, wanted);
                        writeU32(split + used_in_block, 0);
                        writeU8(split + status_in_block, @intFromEnum(Status.free));
                        return split;
                    }
                    return block;
                }
            }
            return none;
        }

        fn allocBlock(count: u64) u64 {
            const position = readU64(position_at);
            const tracked = readU64(length_at);
            // Upstream casts the position to a wasm32 pointer.
            const current = address(blocks_offset +% position);
            const left = tracked -% position -% root_size;
            const with_header = count +% block_header_size;
            if (with_header >= left) {
                if (with_header <= position) {
                    const block = findFreeBlock(count, position);
                    // Where upstream traps, the allocation fails and nothing changes.
                    if (block == walk_failed) return none;
                    if (block != none) {
                        writeU32(block + used_in_block, @truncate(count));
                        writeU8(block + status_in_block, @intFromEnum(Status.active));
                        return block;
                    }
                }
                const pages: u32 = @truncate(numPages(with_header -% left));
                if (!Memory.grow(pages)) return none;
                writeU64(length_at, tracked +% @as(u64, pages) *% page_size);
            }
            if (!inMemory(current, block_header_size)) return none;
            writeU64(position_at, position +% with_header);
            writeU8(current + status_in_block, @intFromEnum(Status.active));
            writeU32(current + size_in_block, @truncate(count));
            writeU32(current + used_in_block, @truncate(count));
            return current;
        }

        fn findBlock(offset: u64) u64 {
            if (!inBoundsFast(offset)) return none;
            var block = blocks_offset;
            while (block < blocks_offset +% offset) : (block = nextBlock(block)) {
                // Where upstream reads a status or a size outside the memory, it traps; here no block is found.
                if (!inMemory(block + status_in_block, 1)) return none;
                if (readU8(block + status_in_block) == @intFromEnum(Status.active) and
                    address(block + block_header_size) == offset) return block;
                if (!inMemory(block + size_in_block, 4)) return none;
            }
            return none;
        }

        pub fn alloc(count: u64) u64 {
            if (count == 0) return 0;
            root();
            const block = allocBlock(count);
            if (block == none) return 0;
            return address(block + block_header_size);
        }

        pub fn free(handle: u64) void {
            if (handle == 0) return;
            root();
            const block = findBlock(handle);
            if (block == none) return;
            writeU8(block + status_in_block, @intFromEnum(Status.free));
            if (handle == readU64(input_offset_at)) writeU64(input_length_at, 0);
        }

        pub fn lengthUnsafe(handle: u64) u64 {
            if (handle == 0 or !inBoundsFast(handle)) return 0;
            const block = handle - block_header_size;
            if (readU8(block + status_in_block) != @intFromEnum(Status.active)) return 0;
            return readU32(block + used_in_block);
        }

        pub fn length(handle: u64) u64 {
            if (handle == 0) return 0;
            root();
            const block = findBlock(handle);
            if (block == none) return 0;
            return readU32(block + used_in_block);
        }

        pub fn loadU8(p: u64) u8 {
            if (!accessible(p, 1)) return 0;
            return readU8(p);
        }

        pub fn loadU64(p: u64) u64 {
            if (!accessible(p, 8)) return 0;
            return readU64(p);
        }

        pub fn inputLoadU8(offset: u64) u8 {
            root();
            if (offset >= readU64(input_length_at)) return 0;
            return loadU8(readU64(input_offset_at) +% offset);
        }

        pub fn inputLoadU64(offset: u64) u64 {
            root();
            if (offset +% 8 > readU64(input_length_at)) return 0;
            return loadU64(readU64(input_offset_at) +% offset);
        }

        pub fn storeU8(p: u64, value: u8) void {
            if (!accessible(p, 1)) return;
            writeU8(p, value);
        }

        pub fn storeU64(p: u64, value: u64) void {
            if (!accessible(p, 8)) return;
            writeU64(p, value);
        }

        pub fn inputSet(handle: u64, len: u64) void {
            root();
            if (!inBlocks(handle) or !inBlocks(handle +% len -% 1)) return;
            writeU64(input_offset_at, handle);
            writeU64(input_length_at, len);
        }

        pub fn outputSet(handle: u64, len: u64) void {
            root();
            if (!inBlocks(handle) or !inBlocks(handle +% len -% 1)) return;
            writeU64(output_offset_at, handle);
            writeU64(output_length_at, len);
        }

        pub fn inputLength() u64 {
            root();
            return readU64(input_length_at);
        }

        pub fn inputOffset() u64 {
            root();
            return readU64(input_offset_at);
        }

        pub fn outputLength() u64 {
            root();
            return readU64(output_length_at);
        }

        pub fn outputOffset() u64 {
            root();
            return readU64(output_offset_at);
        }

        pub fn reset() void {
            root();
            const position = readU64(position_at);
            writeU64(position_at, 0);
            const end = Memory.size();
            const clear = if (inMemory(blocks_offset, position)) position else end - blocks_offset;
            @memset(Memory.bytes()[@intCast(blocks_offset)..][0..@intCast(clear)], 0);
            writeU64(error_at, 0);
            writeU64(input_offset_at, 0);
            writeU64(input_length_at, 0);
            writeU64(output_offset_at, 0);
            writeU64(output_length_at, 0);
        }

        pub fn errorSet(handle: u64) void {
            root();
            if (handle != 0 and !inBlocks(handle)) return;
            writeU64(error_at, handle);
        }

        pub fn errorGet() u64 {
            root();
            return readU64(error_at);
        }

        pub fn memoryBytes() u64 {
            root();
            return readU64(length_at);
        }
    };
}
