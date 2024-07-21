const std = @import("std");
const Allocator = std.mem.Allocator;

const vm = @import("vm.zig");

fn runMiniVM(allocator: Allocator) !void {
    var VM: vm.MiniVM = undefined;
    try VM.init(allocator);
    defer VM.deinit();
}

pub fn main() !void {}

test "simple test" {
    try runMiniVM(std.testing.allocator);
}
