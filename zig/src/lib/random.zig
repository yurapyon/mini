const std = @import("std");

const kernel = @import("../kernel.zig");
const Kernel = kernel.Kernel;
const Cell = kernel.Cell;

const externals = @import("../externals.zig");
const External = externals.External;

const mem = @import("../memory.zig");

const readFile = @import("../utils/read-file.zig").readFile;

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
});

// ===

pub const Randomizer = struct {
    // TODO allow for using other rngs
    randomizer: std.Random.Xoshiro256,

    pub fn init(self: *@This()) void {
        self.randomizer = std.Random.Xoshiro256.init(0);
    }

    fn random(k: *Kernel, _self: ?*anyopaque) External.Error!void {
        const self: *@This() = @ptrCast(@alignCast(_self));
        const value = self.randomizer.random().int(Cell);
        k.data_stack.pushCell(value);
    }

    fn seedRng(k: *Kernel, _self: ?*anyopaque) External.Error!void {
        const self: *@This() = @ptrCast(@alignCast(_self));
        const seed = k.data_stack.popCell();
        self.randomizer.seed(seed);
    }

    pub fn registerExternals(self: *@This(), k: *Kernel) !void {
        try k.addExternal("random", .{
            .callback = random,
            .userdata = self,
        });
        try k.addExternal(">rng", .{
            .callback = seedRng,
            .userdata = self,
        });
    }
};
