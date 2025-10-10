const c = @import("c.zig").c;
const cgfx = @import("c.zig").gfx;

const random = @import("../utils/random.zig");

const kernel = @import("../kernel.zig");
const Cell = kernel.Cell;
const SignedCell = kernel.SignedCell;

const video = @import("video.zig");

const Palette = @import("palette.zig").Palette;
const PixelBuffer = @import("pixel_buffer.zig").PixelBuffer;

// ===

const brush_width = 7;

pub const Pixels = struct {
    const shader_strings = struct {
        const vert = @embedFile("shaders/pixels_vert.glsl");
        const frag = @embedFile("shaders/pixels_frag.glsl");
    };

    const quad_data = [_]f32{
        1.0,  1.0,  1.0, 1.0,
        -1.0, 1.0,  0.0, 1.0,
        1.0,  -1.0, 1.0, 0.0,
        -1.0, -1.0, 0.0, 0.0,
    };

    palette: Palette(16),
    buffer: PixelBuffer(video.screen_width, video.screen_height),
    brush: [brush_width * brush_width]u8,

    vao: c.GLuint,
    vbo: c.GLuint,
    program: c.GLuint,

    locations: struct {
        texture: c.GLint,
        palette: c.GLint,
    },

    pub fn init(self: *@This()) void {
        self.palette.init();
        self.buffer.init();
        self.buffer.randomize(16);

        self.vao = cgfx.vertex_array.create();
        self.initQuad();
        self.initProgram();

        c.glUseProgram(self.program);
        c.glUniform1i(self.locations.texture, 0);

        self.palette.updateProgramUniforms(self.locations.palette);
        self.buffer.pushToTexture();
    }

    fn initProgram(self: *@This()) void {
        const vert_shader = cgfx.shader.create(
            shader_strings.vert,
            c.GL_VERTEX_SHADER,
        );
        defer cgfx.shader.deinit(vert_shader);

        const frag_shader = cgfx.shader.create(
            shader_strings.frag,
            c.GL_FRAGMENT_SHADER,
        );
        defer cgfx.shader.deinit(frag_shader);

        self.program = cgfx.program.create(
            vert_shader,
            frag_shader,
        );

        self.locations.texture = c.glGetUniformLocation(
            self.program,
            "tex",
        );
        self.locations.palette = c.glGetUniformLocation(
            self.program,
            "palette",
        );
    }

    fn initQuad(self: *@This()) void {
        self.vbo = cgfx.buffer.create();

        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.vbo);
        c.glBufferData(
            c.GL_ARRAY_BUFFER,
            @sizeOf(@TypeOf(quad_data)),
            &quad_data,
            c.GL_STATIC_DRAW,
        );

        c.glBindVertexArray(self.vao);

        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(
            0,
            2,
            c.GL_FLOAT,
            c.GL_FALSE,
            4 * @sizeOf(f32),
            @ptrFromInt(0),
        );

        c.glEnableVertexAttribArray(1);
        c.glVertexAttribPointer(
            1,
            2,
            c.GL_FLOAT,
            c.GL_FALSE,
            4 * @sizeOf(f32),
            @ptrFromInt(2 * @sizeOf(f32)),
        );

        c.glBindVertexArray(0);
    }

    pub fn draw(self: *@This()) void {
        c.glUseProgram(self.program);

        c.glBindTexture(c.GL_TEXTURE_2D, self.buffer.texture);
        c.glActiveTexture(c.GL_TEXTURE0);

        c.glBindVertexArray(self.vao);
        c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);

        c.glBindVertexArray(0);
    }

    // ===

    pub fn storePalette(self: *@This(), addr: Cell, value: u8) void {
        if (addr < @TypeOf(self.palette).item_ct) {
            self.palette.colors[addr] = value;
            c.glUseProgram(self.program);
            self.palette.updateProgramUniforms(self.locations.palette);
        }
    }

    pub fn fetchPalette(self: @This(), addr: Cell) u8 {
        if (addr < @TypeOf(self.palette).item_ct) {
            return self.palette.colors[addr];
        } else {
            return 0;
        }
    }

    pub fn storeBrush(self: *@This(), addr: Cell, value: u8) void {
        if (addr < brush_width * brush_width) {
            self.brush[addr] = value;
        }
    }

    pub fn fetchBrush(self: @This(), addr: Cell) u8 {
        if (addr < brush_width * brush_width) {
            return self.brush[addr];
        } else {
            return 0;
        }
    }

    pub fn putBrush(
        self: *@This(),
        x: Cell,
        y: Cell,
        palette_idx: u4,
    ) void {
        var i: Cell = 0;
        var j: Cell = 0;
        while (i < brush_width) : (i += 1) {
            while (j < brush_width) : (j += 1) {
                const bw2 = brush_width / 2;

                const bx = x + i;
                const by = y + j;
                const brush = self.brush[i * brush_width + j];
                if (bx >= bw2 and by >= bw2 and brush < 16) {
                    self.buffer.putXY(
                        bx - bw2,
                        by - bw2,
                        palette_idx,
                    );
                }
            }
            j = 0;
        }
    }

    pub fn putPixel(
        self: *@This(),
        x: Cell,
        y: Cell,
        palette_idx: u4,
    ) void {
        self.buffer.putXY(x, y, palette_idx);
    }

    pub fn putLine(
        self: *@This(),
        x0: Cell,
        y0: Cell,
        x1: Cell,
        y1: Cell,
        palette_idx: u4,
    ) void {
        // Adapted from
        // https://en.wikipedia.org/wiki/Bresenham's_line_algorithm

        const sx0 = @as(SignedCell, @intCast(x0));
        const sy0 = @as(SignedCell, @intCast(y0));
        const sx1 = @as(SignedCell, @intCast(x1));
        const sy1 = @as(SignedCell, @intCast(y1));

        const dx = @as(SignedCell, @intCast(@abs(sx1 - sx0)));
        const sx: SignedCell = if (sx0 < sx1) 1 else -1;
        const dy = -@as(SignedCell, @intCast(@abs(sy1 - sy0)));
        const sy: SignedCell = if (sy0 < sy1) 1 else -1;

        var e = dx + dy;
        var x = sx0;
        var y = sy0;

        while (true) {
            self.buffer.putXY(
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
        x0: Cell,
        y0: Cell,
        x1: Cell,
        y1: Cell,
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

    pub fn putBrushLine(
        self: *@This(),
        x0: Cell,
        y0: Cell,
        x1: Cell,
        y1: Cell,
        palette_idx: u4,
    ) void {
        // Adapted from
        // https://en.wikipedia.org/wiki/Bresenham's_line_algorithm

        const sx0 = @as(SignedCell, @intCast(x0));
        const sy0 = @as(SignedCell, @intCast(y0));
        const sx1 = @as(SignedCell, @intCast(x1));
        const sy1 = @as(SignedCell, @intCast(y1));

        const dx = @as(SignedCell, @intCast(@abs(sx1 - sx0)));
        const sx: SignedCell = if (sx0 < sx1) 1 else -1;
        const dy = -@as(SignedCell, @intCast(@abs(sy1 - sy0)));
        const sy: SignedCell = if (sy0 < sy1) 1 else -1;

        var e = dx + dy;
        var x = sx0;
        var y = sy0;

        while (true) {
            self.putBrush(
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

    pub fn update(self: *@This()) void {
        self.buffer.pushToTexture();
    }
};
