const std = @import("std");

const System = @import("system/system.zig").System;

// pub fn readFile(allocator: Allocator, filename: []const u8) ![]u8 {
//     var file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
//     defer file.close();
//     return file.readToEndAlloc(allocator, std.math.maxInt(usize));
// }

pub fn main() !void {
    // try runMiniVM(std.heap.c_allocator);
    var system: System = undefined;

    try system.init(std.heap.c_allocator);
    defer system.deinit();

    try system.start();
    defer system.stop();

    try system.mainLoop();
}

test "lib-testing" {
    _ = @import("stack.zig");
    _ = @import("utils.zig");
    _ = @import("register.zig");
    _ = @import("input_source.zig");
    _ = @import("dictionary.zig");
    _ = @import("memory.zig");
    _ = @import("mini.zig");
}

test "end-to-end" {
    // try runMiniVM(std.testing.allocator);
}
