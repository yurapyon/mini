const c = @import("c.zig");

const random = @import("../utils/random.zig");

const runtime = @import("../runtime.zig");
const Cell = runtime.Cell;

const video = @import("video.zig");

// ===

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

    palette: [16 * 3]u8,
    buffer: [256 * 1024]u8,

    texture: c.GLuint,
    vbo: c.GLuint,
    vao: c.GLuint,
    program: c.GLuint,

    locations: struct {
        texture: c.GLint,
        palette: c.GLint,
    },

    pub fn init(self: *@This()) void {
        self.texture = c.gfx.texture.createEmpty(
            video.screen_width,
            video.screen_height,
        );
        self.initQuad();
        self.initProgram();

        c.glUseProgram(self.program);
        c.glUniform1i(self.locations.texture, 0);

        random.fillWithRandomBytes(&self.buffer);
        for (&self.buffer) |*color| {
            color.* %= 16;
        }
        self.pushBufferToTexture();

        random.fillWithRandomBytes(&self.palette);
        self.setPaletteUniforms();
    }

    fn initProgram(self: *@This()) void {
        const vert_shader = c.gfx.shader.create(
            shader_strings.vert,
            c.GL_VERTEX_SHADER,
        );
        defer c.gfx.shader.deinit(vert_shader);

        const frag_shader = c.gfx.shader.create(
            shader_strings.frag,
            c.GL_FRAGMENT_SHADER,
        );
        defer c.gfx.shader.deinit(frag_shader);

        self.program = c.gfx.program.create(
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
        self.vbo = c.gfx.buffer.create();

        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.vbo);
        c.glBufferData(
            c.GL_ARRAY_BUFFER,
            @sizeOf(@TypeOf(quad_data)),
            &quad_data,
            c.GL_STATIC_DRAW,
        );

        self.vao = c.gfx.vertex_array.create();

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

    pub fn pushBufferToTexture(self: *@This()) void {
        c.glBindTexture(c.GL_TEXTURE_2D, self.texture);
        c.glTexSubImage2D(
            c.GL_TEXTURE_2D,
            0,
            0,
            0,
            video.screen_width,
            video.screen_height,
            c.GL_RED,
            c.GL_UNSIGNED_BYTE,
            &self.buffer,
        );
    }

    pub fn setPaletteUniforms(self: *@This()) void {
        var float_palette = [_]f32{0} ** (16 * 3);
        for (self.palette, 0..) |byte, i| {
            float_palette[i] = @as(f32, @floatFromInt(byte)) / 255;
        }
        c.glUniform3fv(
            self.locations.palette,
            16,
            &float_palette,
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

    // ===

    pub fn store(self: *@This(), addr: Cell, value: u8) void {
        if (addr < @sizeOf(@TypeOf(self.palette))) {
            self.palette[addr] = value;
            self.setPaletteUniforms();
        }
    }

    pub fn fetch(self: *@This(), addr: Cell) u8 {
        if (addr < @sizeOf(@TypeOf(self.palette))) {
            return self.palette[addr];
        } else {
            return 0;
        }
    }

    pub fn putPixel(
        self: *@This(),
        x: Cell,
        y: Cell,
        palette_idx: u4,
    ) void {
        const at = @as(usize, x) + @as(usize, y) * video.screen_width;
        self.buffer[at] = palette_idx;
    }
};
