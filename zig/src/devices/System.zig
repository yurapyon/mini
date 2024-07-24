const std = @import("std");

const vm = @import("../mini.zig");

pub const System = struct {
    pub fn onActivate(_: @This(), _: *vm.MiniVM) void {
        std.debug.print("activate system\n", .{});
    }
};
