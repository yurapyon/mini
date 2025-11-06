const std = @import("std");
const Allocator = std.mem.Allocator;

const readFile = @import("../../utils/read-file.zig").readFile;

const c = @import("../c.zig").c;

// ===

fn loadImageFromMemory(buf: []u8) ![]u8 {
    var w: c_int = undefined;
    var h: c_int = undefined;
    const raw_data = c.stbi_load_from_memory(
        buf.ptr,
        @intCast(buf.len),
        &w,
        &h,
        null,
        4,
    ) orelse return error.CouldNotLoadImage;
    defer c.stbi_image_free(raw_data);

    return raw_data;
}

pub fn loadImageFromFilepath(
    allocator: Allocator,
    path: []const u8,
) ![]u8 {
    const data = try readFile(allocator, path);
    defer allocator.free(data);
    return loadImageFromMemory(data);
}
