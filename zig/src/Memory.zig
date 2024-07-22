const std = @import("std");
const Allocator = std.mem.Allocator;

const Cell = @import("MiniVM.zig").Cell;

pub const Memory = struct {
    allocator: Allocator,
    memory: []u8,

    pub fn init(self: *@This(), allocator: Allocator, size: usize) Allocator.Error!void {
        self.allocator = allocator;
        self.memory = try allocator.allocWithOptions(
            u8,
            size,
            @alignOf(Cell),
            null,
        );
    }

    pub fn deinit(self: @This()) void {
        self.allocator.free(self.memory);
    }

    pub fn byteAt(self: *@This(), addr: Cell) *u8 {
        return &self.memory[addr];
    }

    pub fn cellAt(self: *@This(), addr: Cell) *Cell {
        return @ptrCast(@alignCast(&self.memory[addr]));
    }
};
