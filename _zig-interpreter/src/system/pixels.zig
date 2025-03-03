const c = @import("c.zig");

const random = @import("../utils/random.zig");

const runtime = @import("../runtime.zig");
const Cell = runtime.Cell;

const video = @import("video.zig");

const Palette = @import("palette.zig").Palette;
const PixelBuffer = @import("pixel_buffer.zig").PixelBuffer;

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

    palette: Palette(16),
    buffer: PixelBuffer(video.screen_width, video.screen_height),

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

        self.vao = c.gfx.vertex_array.create();
        self.initQuad();
        self.initProgram();

        c.glUseProgram(self.program);
        c.glUniform1i(self.locations.texture, 0);

        self.palette.updateProgramUniforms(self.locations.palette);
        self.buffer.pushToTexture();
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

    pub fn store(self: *@This(), addr: Cell, value: u8) void {
        if (addr < @TypeOf(self.palette).item_ct) {
            self.palette.colors[addr] = value;
            c.glUseProgram(self.program);
            self.palette.updateProgramUniforms(self.locations.palette);
        }
    }

    pub fn fetch(self: @This(), addr: Cell) u8 {
        if (addr < @TypeOf(self.palette).item_ct) {
            return self.palette.colors[addr];
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
        self.buffer.putXY(x, y, palette_idx);
    }

    pub fn update(self: *@This()) void {
        self.buffer.pushToTexture();
    }
};
