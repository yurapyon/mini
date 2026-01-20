const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const kernel = @import("kernel.zig");
const Kernel = kernel.Kernel;
const Cell = kernel.Cell;

const bytecodes = @import("bytecodes.zig");

pub const External = struct {
    pub const Error = error{
        // TODO get rid of this probably
        ExternalPanic,
    } || bytecodes.Error;

    pub const Callback = *const fn (
        k: *Kernel,
        userdata: ?*anyopaque,
    ) Error!void;

    name: []const u8,
    callback: Callback,
    userdata: ?*anyopaque,

    pub fn call(self: @This(), k: *Kernel) !void {
        try self.callback(k, self.userdata);
    }
};

pub const ExternalsList = struct {
    allocator: Allocator,
    externals: ArrayList(External),

    pub fn init(self: *@This(), allocator: Allocator) void {
        self.allocator = allocator;
        self.externals = .empty;
    }

    pub fn deinit() void {
        // TODO
    }

    // TODO
    // rename to pushExternals or addExternals or something
    pub fn pushSlice(self: *@This(), exts: []const External) !void {
        try self.externals.appendSlice(self.allocator, exts);
    }

    pub fn lookup(self: *@This(), name: []const u8) ?Cell {
        for (self.externals.items, 0..) |external, i| {
            if (std.mem.eql(u8, external.name, name)) {
                return @intCast(i);
            }
        }

        return null;
    }
};
