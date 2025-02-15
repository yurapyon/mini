const c = @import("c.zig");

const runtime = @import("../runtime.zig");
const Cell = runtime.Cell;

const Pixels = @import("pixels.zig").Pixels;
const Characters = @import("characters.zig").Characters;

// ===

// Inspired by pc-98
// 640x400, 4bit color, 24bit palette
// 80x25 character mode, 8bit "attributes" ie, blinking, reverse, etc and 16 color
//   7x11 characters, drawn in 8x16 boxes
// 80x40 character mode
//   7x9 characters, drawn in 8x10 boxes

// Character buffer on top of pixel buffer

// Note
// Pixel buffer isn't exposed to forth
//   pixel writes are done through pixelSet(x, y, color)-type
//     interfaces only
// Other buffers & palettes are directly accesible from forth

pub const screen_width = 640;
pub const screen_height = 400;

const Attributes = packed struct {
    _0: u1,
    _1: u1,
    _2: u1,
    reverse: u1,
    bold: u1,
    color: u3,
};

pub const Video = struct {
    pixels: Pixels,
    characters: Characters,

    pub fn init(self: *@This()) void {
        self.makeTexture();
        self.makeQuad();
        self.makeProgram();

        self.initLocations();

        c.glUseProgram(self.program);
        c.glUniform1i(self.locations.diffuse, 0);

        self.clearBuffer();
        self.updateTexture();
    }

    pub fn deinit(_: *@This()) void {
        // TODO
    }

    // ===

    fn makeQuad(self: *@This()) void {
        var vbo: c.GLuint = undefined;
        c.glGenBuffers(1, &vbo);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        const data = [_]f32{
            1.0,  1.0,  1.0, 1.0,
            -1.0, 1.0,  0.0, 1.0,
            1.0,  -1.0, 1.0, 0.0,
            -1.0, -1.0, 0.0, 0.0,
        };
        c.glBufferData(
            c.GL_ARRAY_BUFFER,
            @sizeOf(@TypeOf(data)),
            &data,
            c.GL_STATIC_DRAW,
        );

        self.vbo = vbo;

        var vao: c.GLuint = undefined;
        c.glGenVertexArrays(1, &vao);
        c.glBindVertexArray(vao);

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

        self.vao = vao;
    }

    fn makeProgram(self: *@This()) void {
        _ = self;
        //         const vert_shader = gfx.shader.create(
        //             gfx.vert_shader_string,
        //             c.GL_VERTEX_SHADER,
        //         );
        //         defer gfx.shader.deinit(vert_shader);
        //
        //         const frag_shader = gfx.shader.create(
        //             gfx.frag_shader_string,
        //             c.GL_FRAGMENT_SHADER,
        //         );
        //         defer gfx.shader.deinit(frag_shader);
        //
        //         const program = gfx.program.create(vert_shader, frag_shader);
        //         self.program = program;
    }
};
