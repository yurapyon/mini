const c = @import("c.zig").c;
const cgfx = @import("c.zig").gfx;

const random = @import("../utils/random.zig");

pub fn PixelBuffer(
    comptime width: usize,
    comptime height: usize,
) type {
    return struct {
        buffer: [width * height]u8,
        texture: c.GLuint,

        pub fn init(self: *@This()) void {
            self.texture = cgfx.texture.createEmpty(
                width,
                height,
            );
        }

        pub fn deinit(self: *@This()) void {
            // TODO
            _ = self;
        }

        // ===

        pub fn pushToTexture(self: @This()) void {
            c.glBindTexture(c.GL_TEXTURE_2D, self.texture);
            c.glTexSubImage2D(
                c.GL_TEXTURE_2D,
                0,
                0,
                0,
                width,
                height,
                c.GL_RED,
                c.GL_UNSIGNED_BYTE,
                &self.buffer,
            );
        }

        // ===

        pub fn randomize(self: *@This(), palette_size: u8) void {
            random.fillWithRandomBytes(&self.buffer);
            for (&self.buffer) |*color| {
                color.* %= palette_size;
            }
        }

        pub fn putXY(
            self: *@This(),
            x: usize,
            y: usize,
            palette_idx: u8,
        ) void {
            const at = x + y * width;
            self.buffer[at] = palette_idx;
        }
    };
}
