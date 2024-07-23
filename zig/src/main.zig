const std = @import("std");
const Allocator = std.mem.Allocator;

const vm = @import("MiniVM.zig");

fn runMiniVM(allocator: Allocator) !void {
    const mem = try allocator.allocWithOptions(
        u8,
        vm.max_memory_size,
        @alignOf(vm.Cell),
        null,
    );
    defer allocator.free(mem);

    var vmInstance: vm.MiniVM = undefined;
    try vmInstance.init(mem);
    defer vmInstance.deinit();

    vmInstance.setInputBuffer("1 dup dup\n");
    try vmInstance.interpretLoop();
}

pub fn main() !void {}

test "simple test" {
    _ = @import("Stack.zig");
    _ = @import("WordHeader.zig");
    _ = @import("utils.zig");

    try runMiniVM(std.testing.allocator);
}
