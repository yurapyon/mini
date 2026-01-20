const std = @import("std");
const Allocator = std.mem.Allocator;

const mini = @import("mini");

const kernel = mini.kernel;
const Cell = kernel.Cell;
const SignedCell = kernel.SignedCell;

const random = mini.utils.random;

const c = @import("c.zig").c;
const cgfx = @import("c.zig").gfx;

const system = @import("system.zig");

const Palette = @import("palette.zig").Palette;
const Image = @import("image.zig").Image;

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
    image: Image,
    texture: c.GLuint,

    vao: c.GLuint,
    vbo: c.GLuint,
    program: c.GLuint,

    locations: struct {
        texture: c.GLint,
        palette: c.GLint,
    },

    pub fn init(self: *@This(), allocator: Allocator) !void {
        self.palette.init();
        try self.initBuffer(allocator);

        self.vao = cgfx.vertex_array.create();
        self.initQuad();
        self.initProgram();

        c.glUseProgram(self.program);
        c.glUniform1i(self.locations.texture, 0);

        self.palette.updateProgramUniforms(self.locations.palette);
    }

    fn initBuffer(self: *@This(), allocator: Allocator) !void {
        try self.image.init(
            allocator,
            system.screen_width,
            system.screen_height,
        );
        self.image.randomize(16);

        self.texture = cgfx.texture.createEmpty(
            @intCast(self.image.width),
            @intCast(self.image.height),
        );

        self.image.pushToTexture(self.texture);
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

    pub fn deinit(self: *@This()) void {
        // TODO deinit
        _ = self;
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

    pub fn paletteStore(self: *@This(), addr: Cell, value: u8) void {
        if (addr < @TypeOf(self.palette).item_ct) {
            self.palette.colors[addr] = value;
        }
    }

    pub fn paletteFetch(self: @This(), addr: Cell) u8 {
        if (addr < @TypeOf(self.palette).item_ct) {
            return self.palette.colors[addr];
        } else {
            return 0;
        }
    }

    pub fn update(self: *@This()) void {
        c.glUseProgram(self.program);
        self.palette.updateProgramUniforms(self.locations.palette);

        self.image.pushToTexture(self.texture);
    }
};
