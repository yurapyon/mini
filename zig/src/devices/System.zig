const std = @import("std");

const MiniVM = @import("../vm.zig").MiniVM;

pub const System = struct {
    pub fn onActivate(_: @This(), _: *MiniVM) void {
        std.debug.print("activate system\n", .{});
    }
};
