const std = @import("std");
const Allocator = std.Allocator;

const mini = @import("mini");

const kernel = mini.kernel;
const Kernel = kernel.Kernel;
const Cell = kernel.Cell;

const externals = @import("externals.zig");
const External = externals.External;
const ExternalsList = externals.ExternalsList;

const mem = mini.mem;

// ===

// TODO
// Float pool
// 'floats' are an index on the stack
//  slows down math but makes it so you can reuse all th existing dup/swap/drop words

pub const Floats = struct {
    floats: []f32,
    indices: []Cell,
    alive_ct: Cell,

    pub fn init(self: *@This(), allocator: Allocator, size: Cell) void {
        self.floats = try allocator.alloc(f32, size);
        self.indices = try allocator.alloc(Cell, size);
        self.alive_ct = 0;
    }

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        allocator.free(self.floats);
        allocator.free(self.indices);
    }
};
