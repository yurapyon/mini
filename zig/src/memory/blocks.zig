const std = @import("std");

const runtime = @import("../runtime.zig");
const Cell = runtime.Cell;

// ===

// TODO
// serialized/deserialized with plain text ?

pub const Blocks = struct {
    const block_size = 1024;

    memory: [256 * block_size]u8,
    memory_size: usize,

    pub fn init(self: *@This()) void {
        self.memory_size = 0;
    }

    pub fn serialize(self: @This()) void {
        _ = self;
        // write length ?
        // write memory up to length
    }

    pub fn deserialize(self: *@This(), input: []const u8) !void {
        _ = self;
        _ = input;
    }

    pub fn readFromBlock(
        self: *@This(),
        block_id: Cell,
        memory: [block_size]u8,
    ) void {
        const start = block_id * block_size;
        const end = start + block_size;
        @memcpy(memory, self.memory[start..end]);
    }

    pub fn writeToBlock(
        self: *@This(),
        block_id: Cell,
        memory: [block_size]u8,
    ) void {
        const start = block_id * block_size;
        const end = start + block_size;
        @memcpy(self.memory[start..end], memory);
    }
};
