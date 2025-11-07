const std = @import("std");
const Allocator = std.mem.Allocator;

const c = @import("c.zig").c;
const cgfx = @import("c.zig").gfx;

const random = @import("../utils/random.zig");

const loadImageFromFilepath = @import("utils/load-image.zig").loadImageFromFilepath;

// ===

// NOTE
// Image.data is an array of palette colors
pub const Image = struct {
    width: usize,
    height: usize,
    data: []u8,

    pub fn init(self: *@This(), allocator: Allocator, width: usize, height: usize) !void {
        self.width = width;
        self.height = height;
        self.data = try allocator.alloc(u8, width * height);
    }

    pub fn initFromFile(self: *@This(), allocator: Allocator, filepath: []const u8) !void {
        // TODO check if this needs to be flipped when converting
        const img = try loadImageFromFilepath(allocator, filepath);
        defer allocator.free(img.data);

        try self.init(
            allocator,
            @intCast(img.width),
            @intCast(img.height),
        );

        var i: usize = 0;
        while (i < img.data.len) : (i += 4) {
            const r = img.data[i + 0];
            const g = img.data[i + 1];
            const b = img.data[i + 2];
            const a = img.data[i + 3];

            _ = r;
            _ = g;
            _ = b;

            // TODO better mapping
            const palette: u8 = if (a > 0) 1 else 0;

            self.data[i / 4] = palette;
        }

        std.debug.print("img {} {} {} {}\n", .{
            self.width,
            self.height,
            self.data.len,
            img.data.len,
        });
    }

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        allocator.free(self.data);
    }

    // ===

    pub fn pushToTexture(self: @This(), texture: c.GLuint) void {
        c.glBindTexture(c.GL_TEXTURE_2D, texture);
        c.glTexSubImage2D(
            c.GL_TEXTURE_2D,
            0,
            0,
            0,
            @intCast(self.width),
            @intCast(self.height),
            c.GL_RED,
            c.GL_UNSIGNED_BYTE,
            self.data.ptr,
        );
    }

    // ===

    pub fn fill(self: *@This(), color: u8) void {
        for (self.data) |*pixel| {
            pixel.* = color;
        }
    }

    pub fn randomize(self: *@This(), palette_size: u8) void {
        random.fillWithRandomBytes(self.data);
        for (self.data) |*color| {
            color.* %= palette_size;
        }
    }

    pub fn getXY(self: @This(), x: isize, y: isize) u8 {
        if (x < 0 or y < 0 or x > self.width or y > self.height) {
            return 0;
        }

        const ux: usize = @intCast(x);
        const uy: usize = @intCast(y);

        const at = ux + uy * self.width;
        return self.data[at];
    }

    pub fn putXY(
        self: *@This(),
        x: isize,
        y: isize,
        color: u8,
    ) void {
        if (x < 0 or y < 0 or x > self.width or y > self.height) {
            return;
        }

        const ux: usize = @intCast(x);
        const uy: usize = @intCast(y);

        const at = ux + uy * self.width;
        self.data[at] = color;
    }

    pub fn putLine(
        self: *@This(),
        x0: isize,
        y0: isize,
        x1: isize,
        y1: isize,
        color: u8,
    ) void {
        // Adapted from
        // https://en.wikipedia.org/wiki/Bresenham's_line_algorithm

        const dx = @as(isize, @intCast(@abs(x1 - x0)));
        const sx: isize = if (x0 < x1) 1 else -1;
        const dy = -@as(isize, @intCast(@abs(y1 - y0)));
        const sy: isize = if (y0 < y1) 1 else -1;

        var e = dx + dy;
        var x = x0;
        var y = y0;

        while (true) {
            self.putXY(
                x,
                y,
                color,
            );
            const e2 = 2 * e;
            if (e2 >= dy) {
                if (x == x1) break;
                e += dy;
                x += sx;
            }
            if (e2 <= dx) {
                if (y == y1) break;
                e += dx;
                y += sy;
            }
        }
    }

    pub fn putRect(
        self: *@This(),
        x0: isize,
        y0: isize,
        x1: isize,
        y1: isize,
        palette_idx: u8,
    ) void {
        var x = x0;
        var y = y0;
        while (y < y1) : (y += 1) {
            while (x < x1) : (x += 1) {
                self.putXY(x, y, palette_idx);
            }
            x = x0;
        }
    }

    pub fn blitXY(
        self: *@This(),
        other: Image,
        transparent: u8,
        x: isize,
        y: isize,
    ) void {
        var i: isize = 0;
        var j: isize = 0;
        while (i < other.width) : (i += 1) {
            while (j < other.height) : (j += 1) {
                const other_value = other.getXY(i, j);
                if (other_value != transparent) {
                    self.putXY(
                        x + i,
                        y + j,
                        other_value,
                    );
                }
            }
            j = 0;
        }
    }

    pub fn blitLine(
        self: *@This(),
        other: Image,
        transparent: u8,
        x0: isize,
        y0: isize,
        x1: isize,
        y1: isize,
    ) void {
        // Adapted from
        // https://en.wikipedia.org/wiki/Bresenham's_line_algorithm

        const dx = @as(isize, @intCast(@abs(x1 - x0)));
        const sx: isize = if (x0 < x1) 1 else -1;
        const dy = -@as(isize, @intCast(@abs(y1 - y0)));
        const sy: isize = if (y0 < y1) 1 else -1;

        var e = dx + dy;
        var x = x0;
        var y = y0;

        while (true) {
            self.blitXY(
                other,
                transparent,
                x,
                y,
            );
            const e2 = 2 * e;
            if (e2 >= dy) {
                if (x == x1) break;
                e += dy;
                x += sx;
            }
            if (e2 <= dx) {
                if (y == y1) break;
                e += dx;
                y += sy;
            }
        }
    }
};
