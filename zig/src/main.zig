const std = @import("std");
const Allocator = std.mem.Allocator;

const vm = @import("MiniVM.zig");

fn runMiniVM(allocator: Allocator) !void {
    const mem = try vm.allocateMemory(allocator);
    defer allocator.free(mem);

    var vm_instance: vm.MiniVM = undefined;
    try vm_instance.init(mem);

    vm_instance.input_source.setInputBuffer("1 dup dup\n");
    try vm_instance.repl();
}

pub fn main() !void {}

test "simple test" {
    _ = @import("Stack.zig");
    _ = @import("WordHeader.zig");
    _ = @import("utils.zig");
    _ = @import("Register.zig");
    _ = @import("InputSource.zig");
    _ = @import("Dictionary.zig");

    try runMiniVM(std.testing.allocator);
}
