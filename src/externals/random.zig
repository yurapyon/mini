const std = @import("std");

const mini = @import("mini");

const kernel = mini.kernel;
const Kernel = kernel.Kernel;
const Cell = kernel.Cell;

const externals = @import("externals.zig");
const External = externals.External;
const ExternalsList = externals.ExternalsList;

const mem = mini.mem;

const readFile = mini.utils.readFile;

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

    fn shuffle(k: *Kernel, _self: ?*anyopaque) External.Error!void {
        const self: *@This() = @ptrCast(@alignCast(_self));

        const len = k.data_stack.popCell();
        const addr = k.data_stack.popCell();

        const array = try mem.cellSliceFromAddrAndLen(
            k.memory,
            addr,
            len,
        );

        self.randomizer.random().shuffle(Cell, array);
    }

    fn shuffleC(k: *Kernel, _self: ?*anyopaque) External.Error!void {
        const self: *@This() = @ptrCast(@alignCast(_self));

        const len = k.data_stack.popCell();
        const addr = k.data_stack.popCell();

        const array = try mem.sliceFromAddrAndLen(
            k.memory,
            addr,
            len,
        );

        self.randomizer.random().shuffle(u8, array);
    }

    pub fn pushExternals(self: *@This(), exts: *ExternalsList) !void {
        try exts.pushSlice(&.{
            .{
                .name = "random",
                .callback = random,
                .userdata = self,
            },
            .{
                .name = ">rng",
                .callback = seedRng,
                .userdata = self,
            },
            .{
                .name = "shuffle",
                .callback = shuffle,
                .userdata = self,
            },
            .{
                .name = "shufflec",
                .callback = shuffle,
                .userdata = self,
            },
        });
    }

    pub fn getStartupFile(_: *@This()) []const u8 {
        return @embedFile("random.mini.fth");
    }
};
