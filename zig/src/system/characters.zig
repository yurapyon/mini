const std = @import("std");
const Allocator = std.mem.Allocator;

const c = @import("c.zig").c;
const cgfx = @import("c.zig").gfx;

const kernel = @import("../kernel.zig");
const Cell = kernel.Cell;

const system = @import("system.zig");

const math = @import("math.zig");

const random = @import("../utils/random.zig");

const Palette = @import("palette.zig").Palette;
const Image = @import("image.zig").Image;

// ===

const buffer_width = 80;
const buffer_height = 40;
const character_width = 8;
const character_height = 10;

// TODO blinking, dropshadow, italic
const Attributes = packed struct {
    _0: u1,
    _1: u1,
    _2: u1,
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
        1, 1, 1, 1,
        0, 1, 0, 1,
        1, 0, 1, 0,
        0, 0, 0, 0,
    };

    palette: Palette(8),
    spritesheet: Image,
    // TODO rename
    texture: c.GLuint,
    characters: [buffer_width * buffer_height * 2]u32,

    screen: math.m3.Mat3,
    vao: c.GLuint,
    quad_vbo: c.GLuint,
    instance_vbo: c.GLuint,
    program: c.GLuint,

    locations: struct {
        spritesheet: c.GLint,
        palette: c.GLint,
        screen: c.GLint,
    },

    pub fn init(self: *@This(), allocator: Allocator) !void {
        self.palette.init();

        try self.initBuffers(allocator);

        math.m3.orthoScreen(
            &self.screen,
            system.screen_width,
            system.screen_height,
        );

        // TODO make sure this has to be 2,2 and not 0.5,0.5
        // var temp: math.m3.Mat3 = undefined;
        // math.m3.scaling(&temp, 2, 2);
        // math.m3.mult(&self.screen, temp);

        self.vao = cgfx.vertex_array.create();

        self.initQuad();
        self.initInstanceBuffer();
        self.initProgram();

        c.glUseProgram(self.program);
        self.palette.updateProgramUniforms(self.locations.palette);
    }

    fn initBuffers(self: *@This(), allocator: Allocator) !void {
        for (&self.characters) |*char| {
            char.* = 0;
        }

        // try self.spritesheet.init(
        // allocator,
        // 16 * character_width,
        // 16 * character_height,
        // );

        try self.spritesheet.initFromFile(
            allocator,
            "src/system/content/font.png",
        );

        self.texture = cgfx.texture.createEmpty(
            @intCast(self.spritesheet.width),
            @intCast(self.spritesheet.height),
        );

        self.spritesheet.pushToTexture(self.texture);
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

        self.locations.spritesheet = c.glGetUniformLocation(
            self.program,
            "tex",
        );
        self.locations.palette = c.glGetUniformLocation(
            self.program,
            "palette",
        );
        self.locations.screen = c.glGetUniformLocation(
            self.program,
            "screen",
        );
    }

    fn initQuad(self: *@This()) void {
        self.quad_vbo = cgfx.buffer.create();

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
        self.instance_vbo = cgfx.buffer.create();

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
            @ptrFromInt(1 * @sizeOf(u32)),
        );
        c.glVertexAttribDivisor(3, 1);

        c.glBindVertexArray(0);
    }

    pub fn deinit(self: *@This()) void {
        // TODO
        _ = self;
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
        c.glUseProgram(self.program);
        c.glUniformMatrix3fv(
            self.locations.screen,
            1,
            c.GL_FALSE,
            &self.screen,
        );

        c.glBindTexture(c.GL_TEXTURE_2D, self.texture);
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

    pub fn paletteStore(self: *@This(), addr: Cell, value: u8) void {
        if (addr < self.palette.colors.len) {
            self.palette.colors[addr] = value;
        }
    }

    pub fn paletteFetch(self: *@This(), addr: Cell) u8 {
        if (addr < self.palette.colors.len) {
            return self.palette.colors[addr];
        } else {
            return 0;
        }
    }

    pub fn getSpritesheet(self: *@This()) *Image {
        return self.spritesheet;
    }

    pub fn store(self: *@This(), addr: Cell, value: u8) void {
        if (addr < self.characters.len) {
            self.characters[addr] = value;
        }
    }

    pub fn fetch(self: @This(), addr: Cell) u8 {
        if (addr < self.characters.len) {
            return @truncate(self.characters[addr]);
        } else {
            return 0;
        }
    }

    pub fn update(self: *@This()) void {
        c.glUseProgram(self.program);
        self.palette.updateProgramUniforms(self.locations.palette);

        self.updateInstanceBuffer();
        self.spritesheet.pushToTexture(self.texture);
    }
};
