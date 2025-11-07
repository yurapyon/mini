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

        self.init(allocator, @intCast(img.width), @intCast(img.height));

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
            const palette = if (a > 0) 1 else 0;

            self.data[i / 4] = palette;
        }
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
            self.width,
            self.height,
            c.GL_RED,
            c.GL_UNSIGNED_BYTE,
            &self.data,
        );
    }

    // ===

    pub fn randomize(self: *@This(), palette_size: u8) void {
        random.fillWithRandomBytes(&self.buffer);
        for (&self.buffer) |*color| {
            color.* %= palette_size;
        }
    }

    pub fn getXY(self: *@This(), x: usize, y: usize) u8 {
        const at = x + y * self.width;
        return self.buffer[at];
    }

    pub fn putXY(
        self: *@This(),
        x: usize,
        y: usize,
        palette_idx: u8,
    ) void {
        const at = x + y * self.width;
        self.buffer[at] = palette_idx;
    }

    pub fn putLine(
        self: *@This(),
        x0: usize,
        y0: usize,
        x1: usize,
        y1: usize,
        palette_idx: u4,
    ) void {
        // Adapted from
        // https://en.wikipedia.org/wiki/Bresenham's_line_algorithm

        const sx0 = @as(isize, @intCast(x0));
        const sy0 = @as(isize, @intCast(y0));
        const sx1 = @as(isize, @intCast(x1));
        const sy1 = @as(isize, @intCast(y1));

        const dx = @as(isize, @intCast(@abs(sx1 - sx0)));
        const sx: isize = if (sx0 < sx1) 1 else -1;
        const dy = -@as(isize, @intCast(@abs(sy1 - sy0)));
        const sy: isize = if (sy0 < sy1) 1 else -1;

        var e = dx + dy;
        var x = sx0;
        var y = sy0;

        while (true) {
            self.putXY(
                @intCast(x),
                @intCast(y),
                palette_idx,
            );
            const e2 = 2 * e;
            if (e2 >= dy) {
                if (x == sx1) break;
                e += dy;
                x += sx;
            }
            if (e2 <= dx) {
                if (y == sy1) break;
                e += dx;
                y += sy;
            }
        }
    }

    pub fn putRect(
        self: *@This(),
        x0: usize,
        y0: usize,
        x1: usize,
        y1: usize,
        palette_idx: u4,
    ) void {
        var x = x0;
        var y = y0;
        while (y < y1) : (y += 1) {
            while (x < x1) : (x += 1) {
                self.buffer.putXY(x, y, palette_idx);
            }
            x = x0;
        }
    }

    pub fn blitXY(
        self: *@This(),
        other: Image,
        // TODO allow negatives
        x: usize,
        y: usize,
    ) void {
        var i: usize = 0;
        var j: usize = 0;
        while (i < other.width) : (i += 1) {
            while (j < other.height) : (j += 1) {
                const other_value = other.getXY(i, j);
                // TODO check for overflow
                self.putXY(
                    x + i,
                    y + j,
                    other_value,
                );
            }
            j = 0;
        }
    }

    pub fn blitLine(
        self: *@This(),
        other: Image,
        // TODO allow negatives
        x0: usize,
        y0: usize,
        x1: usize,
        y1: usize,
    ) void {
        // Adapted from
        // https://en.wikipedia.org/wiki/Bresenham's_line_algorithm

        const sx0 = @as(isize, @intCast(x0));
        const sy0 = @as(isize, @intCast(y0));
        const sx1 = @as(isize, @intCast(x1));
        const sy1 = @as(isize, @intCast(y1));

        const dx = @as(isize, @intCast(@abs(sx1 - sx0)));
        const sx: isize = if (sx0 < sx1) 1 else -1;
        const dy = -@as(isize, @intCast(@abs(sy1 - sy0)));
        const sy: isize = if (sy0 < sy1) 1 else -1;

        var e = dx + dy;
        var x = sx0;
        var y = sy0;

        while (true) {
            self.blitXY(
                other,
                @intCast(x),
                @intCast(y),
            );
            const e2 = 2 * e;
            if (e2 >= dy) {
                if (x == sx1) break;
                e += dy;
                x += sx;
            }
            if (e2 <= dx) {
                if (y == sy1) break;
                e += dx;
                y += sy;
            }
        }
    }
};
