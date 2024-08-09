const std = @import("std");

// pub fn readFile(allocator: Allocator, filename: []const u8) ![]u8 {
//     var file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
//     defer file.close();
//     return file.readToEndAlloc(allocator, std.math.maxInt(usize));
// }

pub fn main() !void {}

test "lib-testing" {
    _ = @import("dictionary.zig");
    _ = @import("memory.zig");
    _ = @import("stack.zig");
    _ = @import("utils.zig");
    _ = @import("runtime.zig");
    _ = @import("vm.zig");
}

test "end-to-end" {}
