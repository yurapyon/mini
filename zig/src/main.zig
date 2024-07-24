const std = @import("std");
const Allocator = std.mem.Allocator;

const vm = @import("mini.zig");

fn runMiniVM(allocator: Allocator) !void {
    const mem = try vm.allocateMemory(allocator);
    defer allocator.free(mem);

    var vm_instance: vm.MiniVM = undefined;
    try vm_instance.init(mem);

    vm_instance.input_source.setInputBuffer("1 dup dup\n");
    try vm_instance.repl();
}

pub fn main() !void {}

test "lib-testing" {
    _ = @import("stack.zig");
    _ = @import("word_header.zig");
    _ = @import("utils.zig");
    _ = @import("register.zig");
    _ = @import("input_source.zig");
    _ = @import("dictionary.zig");
    _ = @import("mini.zig");
}

test "end-to-end" {
    // try runMiniVM(std.testing.allocator);
}
