const c = @import("c.zig");

const runtime = @import("../runtime.zig");
const Cell = runtime.Cell;

// ===

pub const Pixels = struct {
    const vert_shader_string = @embedFile("shaders/pixels_vert.glsl");
    const frag_shader_string = @embedFile("shaders/pixels_frag.glsl");

    palette: [16 * 3]u8,
    buffer: [256 * 1024]u8,

    texture: c.GLuint,
    vbo: c.GLuint,
    vao: c.GLuint,
    program: c.GLuint,

    locations: struct {
        diffuse: c.GLint,
        palette: c.GLint,
    },

    pub fn init(self: *@This()) void {
        _ = self;
    }

    fn initLocations(self: *@This()) void {
        self.locations.diffuse = c.glGetUniformLocation(
            self.program,
            "diffuse",
        );
        self.locations.palette = c.glGetUniformLocation(
            self.program,
            "palette",
        );
    }

    pub fn store(self: *@This(), addr: Cell, value: u8) void {
        if (addr < @sizeOf(self.palette)) {
            self.palette[addr] = value;
        }
    }

    pub fn fetch(self: *@This(), addr: Cell) u8 {
        if (addr < @sizeOf(self.palette)) {
            return self.palette[addr];
        } else {
            return 0;
        }
    }

    // TODO
    pub fn putPixel(
        self: *@This(),
        x: Cell,
        y: Cell,
        palette_idx: u4,
    ) void {
        _ = self;
        _ = x;
        _ = y;
        _ = palette_idx;
        // const color = &self.palette[palette_idx];
        // const page_at = page % page_ct;
        // const buffer_at = @as(usize, page_at) * page_size + addr;
        // const buffer_color = self.buffer[buffer_at][0..3];
        // @memcpy(buffer_color, color);
    }

    pub fn updateTexture(self: *@This()) void {
        c.glBindTexture(c.GL_TEXTURE_2D, self.texture);
        c.glTexSubImage2D(
            c.GL_TEXTURE_2D,
            0,
            0,
            0,
            // TODO
            // screen_width,
            // screen_height,
            0,
            0,
            c.GL_RED,
            c.GL_UNSIGNED_BYTE,
            &self.pixels.buffer,
        );
    }

    pub fn draw(self: *@This()) void {
        c.glUseProgram(self.program);

        c.glBindTexture(c.GL_TEXTURE_2D, self.texture);
        c.glActiveTexture(c.GL_TEXTURE0);

        c.glBindVertexArray(self.vao);
        c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);

        c.glBindVertexArray(0);
    }
};
