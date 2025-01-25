const std = @import("std");

const runtime = @import("../runtime.zig");
const Cell = runtime.Cell;

// ===

// Block memory
// serialized/deserialized with plain text ?

pub const Storage = struct {
    // based on screen resolution in video.zig
    // 2048 can be shown in 64x32 chars
    const file_size = 2048;

    memory: [128 * file_size]u8,
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

    pub fn copyFromFile(self: *@This(), file_id: Cell, memory: []u8) void {
        const start = file_id * file_size;
        const end = (file_id + 1) * file_size;
        std.mem.copy(u8, self.memory[start..end], memory);
    }

    pub fn copyToFile(self: *@This(), file_id: Cell, memory: []u8) void {
        _ = self;
        _ = file_id;
        _ = memory;
        // TODO
        // const start = file_id * file_size;
        // const end = (file_id + 1) * file_size;
        // std.mem.copy(u8, self.memory[start..end], memory);
    }
};
