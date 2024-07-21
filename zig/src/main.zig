const std = @import("std");
const Allocator = std.mem.Allocator;

const MiniVM = @import("MiniVM.zig").MiniVM;

fn runMiniVM(allocator: Allocator) !void {
    var vm: MiniVM = undefined;
    try vm.init(allocator);
    defer vm.deinit();
}

pub fn main() !void {}

test "simple test" {
    try runMiniVM(std.testing.allocator);
}
