const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn readFile(allocator: Allocator, filename: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
    defer file.close();
    return file.readToEndAlloc(allocator, std.math.maxInt(usize));
}

pub fn writeFile(
    filename: []const u8,
    bytes: []const u8,
) !void {
    var file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    return file.writeAll(bytes);
}
