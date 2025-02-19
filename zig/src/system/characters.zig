const c = @import("c.zig");

const runtime = @import("../runtime.zig");
const Cell = runtime.Cell;

const video = @import("video.zig");

const math = @import("math.zig");

const random = @import("../utils/random.zig");

const Palette = @import("palette.zig").Palette;

const PixelBuffer = @import("pixel_buffer.zig").PixelBuffer;

// ===

const buffer_width = 80;
const buffer_height = 40;
const character_width = 8;
const character_height = 10;

// TODO blinking
const Attributes = packed struct {
    _0: u1,
    _1: u1,
    _2: u1,
    // TODO make sure reverse works even if no character is set
    reverse: u1,
    bold: u1,
    color: u3,
};

pub const Characters = struct {
    const shader_strings = struct {
        const vert = @embedFile("shaders/characters_vert.glsl");
        const frag = @embedFile("shaders/characters_frag.glsl");
    };

    const quad_data = [_]f32{
        1.0,  1.0,  1.0, 1.0,
        -1.0, 1.0,  0.0, 1.0,
        1.0,  -1.0, 1.0, 0.0,
        -1.0, -1.0, 0.0, 0.0,
    };

    palette: Palette(8),
    spritesheet: PixelBuffer(
        16 * character_width,
        16 * character_height,
    ),
    characters: [buffer_width * buffer_height * 2]u32,

    screen: math.m3.Mat3,
    vao: c.GLuint,
    quad_vbo: c.GLuint,
    instance_vbo: c.GLuint,
    program: c.GLuint,

    locations: struct {
        spritesheet: c.GLint,
        palette: c.GLint,
    },

    pub fn init(self: *@This()) void {
        self.palette.init();

        self.initBuffers();
        self.spritesheet.init();
        self.spritesheet.randomize(2);

        math.m3.orthoScreen(
            &self.screen,
            video.screen_width,
            video.screen_height,
        );

        // TODO make sure this has to be 2,2 and not 0.5,0.5
        var temp: math.m3.Mat3 = undefined;
        math.m3.scaling(&temp, 2, 2);
        math.m3.mult(&self.screen, temp);

        self.vao = c.gfx.vertex_array.create();

        self.initQuad();
        self.initInstanceBuffer();
        self.initProgram();
    }

    fn initBuffers(self: *@This()) void {
        for (&self.characters) |*char| {
            char.* = 0;
        }
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

        self.locations.spritesheet = c.glGetUniformLocation(
            self.program,
            "tex",
        );
        self.locations.palette = c.glGetUniformLocation(
            self.program,
            "palette",
        );
    }

    fn initQuad(self: *@This()) void {
        self.quad_vbo = c.gfx.buffer.create();

        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.quad_vbo);
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

    fn initInstanceBuffer(self: *@This()) void {
        self.instance_vbo = c.gfx.buffer.create();

        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.instance_vbo);
        c.glBufferData(
            c.GL_ARRAY_BUFFER,
            @sizeOf(@TypeOf(self.characters)),
            &self.characters,
            c.GL_DYNAMIC_DRAW,
        );

        c.glBindVertexArray(self.vao);

        c.glEnableVertexAttribArray(2);
        c.glVertexAttribPointer(
            2,
            1,
            c.GL_UNSIGNED_INT,
            c.GL_FALSE,
            2 * @sizeOf(u32),
            @ptrFromInt(0),
        );
        c.glVertexAttribDivisor(2, 1);

        c.glEnableVertexAttribArray(3);
        c.glVertexAttribPointer(
            3,
            1,
            c.GL_UNSIGNED_INT,
            c.GL_FALSE,
            2 * @sizeOf(u32),
            @ptrFromInt(2 * @sizeOf(u32)),
        );
        c.glVertexAttribDivisor(3, 1);

        c.glBindVertexArray(0);
    }

    fn updateInstanceBuffer(self: *@This()) void {
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.instance_vbo);
        c.glBufferSubData(
            c.GL_ARRAY_BUFFER,
            0,
            @sizeOf(@TypeOf(self.characters)),
            &self.characters,
        );
    }

    pub fn draw(self: *@This()) void {
        // TODO write screen matr to program

        c.glUseProgram(self.program);

        c.glBindTexture(c.GL_TEXTURE_2D, self.spritesheet.texture);
        c.glActiveTexture(c.GL_TEXTURE0);

        c.glBindVertexArray(self.vao);
        c.glDrawArraysInstanced(
            c.GL_TRIANGLE_STRIP,
            0,
            4,
            buffer_width * buffer_height,
        );

        c.glBindVertexArray(0);
    }

    // ===

    pub fn store(self: *@This(), addr: Cell, value: u8) void {
        const break0 = @TypeOf(self.palette).item_ct;
        const break1 = break0 + 16 * 16 * 10;
        const break2 = break1 + buffer_width * buffer_height;
        if (addr < break0) {
            self.palette.colors[addr] = value;
            self.palette.updateProgramUniforms(self.locations.palette);
        } else if (addr < break1) {
            const start_addr = (addr - break0) * 8;
            var temp = value;
            var i: usize = 0;
            while (i < 8) : (i += 1) {
                self.spritesheet.buffer[start_addr + 7 - i] = temp & 1;
                temp >>= 1;
            }
            self.spritesheet.pushToTexture();
        } else if (addr < break2) {
            self.characters[addr - break1] = value;
        }
    }

    pub fn fetch(self: @This(), addr: Cell) u8 {
        const break0 = @TypeOf(self.palette).item_ct;
        const break1 = break0 + 16 * 16 * 10;
        const break2 = break1 + buffer_width * buffer_height;
        if (addr < break0) {
            return self.palette.colors[addr];
        } else if (addr < break1) {
            const start_addr = (addr - break0) * 8;
            var value: u8 = 0;
            var i: usize = 0;
            while (i < 8) : (i += 1) {
                const is_set = self.spritesheet.buffer[start_addr + i] > 0;
                value |= if (is_set) 1 else 0;
                value <<= 1;
            }
            return value;
        } else if (addr < break2) {
            return @truncate(self.characters[addr - break1]);
        } else {
            return 0;
        }
    }

    pub fn update(self: *@This()) void {
        self.updateInstanceBuffer();
    }

    // TODO
    //     pub fn putCharacter(
    //         self: *@This(),
    //         x: Cell,
    //         y: Cell,
    //         character_idx: u8,
    //         palette_idx: u8,
    //     ) void {
    //         const character = self.characters[character_idx];
    //         const color = self.palette[palette_idx];
    //
    //         for (0..6) |i| {
    //             // TODO maybe do scr_w and scr_h adjustment in forth
    //             const at_x = x + i + (screen_width - 400) / 2;
    //             var col = character[i];
    //
    //             for (0..8) |j| {
    //                 const at_y = y + j + (screen_height - 300) / 2;
    //                 const value = col & 0x80;
    //
    //                 if (value != 0) {
    //                     const buffer_at = at_x + at_y * screen_width;
    //                     self.buffer[buffer_at] = color;
    //                 }
    //
    //                 col <<= 1;
    //             }
    //         }
    //     }

};
