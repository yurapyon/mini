const std = @import("std");
const Allocator = std.mem.Allocator;

const mini = @import("mini");

const readFile = mini.utils.readFile;

const c = @import("../c.zig").c;

// ===

pub const LoadImageResult = struct {
    data: []u8,
    width: usize,
    height: usize,
};

fn loadImageFromMemory(allocator: Allocator, buf: []u8) !LoadImageResult {
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

    const out = try allocator.alloc(u8, @intCast(w * h * 4));
    @memcpy(out, raw_data);
    return .{
        .data = out,
        .width = @intCast(w),
        .height = @intCast(h),
    };
}

pub fn loadImageFromFilepath(
    allocator: Allocator,
    path: []const u8,
) !LoadImageResult {
    const data = try readFile(allocator, path);
    defer allocator.free(data);
    return loadImageFromMemory(allocator, data);
}
