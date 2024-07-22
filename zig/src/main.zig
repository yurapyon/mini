const std = @import("std");
const Allocator = std.mem.Allocator;

const vm = @import("MiniVM.zig");

fn runMiniVM(allocator: Allocator) !void {
    var vmInstance: vm.MiniVM = undefined;
    try vmInstance.init(allocator);

    vmInstance.setInputBuffer("1 dup dup\n");
    try vmInstance.interpretLoop();

    defer vmInstance.deinit();
}

pub fn main() !void {}

test "simple test" {
    try runMiniVM(std.testing.allocator);
}
