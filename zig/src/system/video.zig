const c = @import("c.zig");

const runtime = @import("../runtime.zig");
const Cell = runtime.Cell;

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
    pixels: struct {
        palette: [16 * 3]u8,
        buffer: [256 * 1024]u8,
    },

    characters: struct {
        palette: [8 * 3]u8,
        sprites: [256 * 10]u8,
        buffer: [80 * 40 * 2]u8,
    },

    texture: c.GLuint,
    vbo: c.GLuint,
    vao: c.GLuint,
    program: c.GLuint,

    locations: struct {
        diffuse: c.GLint,
        palette: c.GLint,
        character_palette: c.GLint,
    },

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

    fn makeTexture(self: *@This()) void {
        var tex: c.GLuint = undefined;
        c.glGenTextures(1, &tex);
        c.glBindTexture(c.GL_TEXTURE_2D, tex);

        c.glTexImage2D(
            c.GL_TEXTURE_2D,
            0,
            c.GL_RGB,
            screen_width,
            screen_height,
            0,
            c.GL_RGB,
            c.GL_UNSIGNED_BYTE,
            null,
        );

        // c.glGenerateMipmap(c.GL_TEXTURE_2D);
        c.glTexParameteri(
            c.GL_TEXTURE_2D,
            c.GL_TEXTURE_WRAP_S,
            c.GL_REPEAT,
        );
        c.glTexParameteri(
            c.GL_TEXTURE_2D,
            c.GL_TEXTURE_WRAP_T,
            c.GL_REPEAT,
        );
        c.glTexParameteri(
            c.GL_TEXTURE_2D,
            c.GL_TEXTURE_MIN_FILTER,
            c.GL_NEAREST,
        );
        c.glTexParameteri(
            c.GL_TEXTURE_2D,
            c.GL_TEXTURE_MAG_FILTER,
            c.GL_NEAREST,
        );

        c.glBindTexture(c.GL_TEXTURE_2D, 0);

        self.texture = tex;
    }

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
        const vert_shader = gfx.shader.create(
            gfx.vert_shader_string,
            c.GL_VERTEX_SHADER,
        );
        defer gfx.shader.deinit(vert_shader);

        const frag_shader = gfx.shader.create(
            gfx.frag_shader_string,
            c.GL_FRAGMENT_SHADER,
        );
        defer gfx.shader.deinit(frag_shader);

        const program = gfx.program.create(vert_shader, frag_shader);
        self.program = program;
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
        self.locations.character_palette = c.glGetUniformLocation(
            self.program,
            "character_palette",
        );
    }

    // ===

    pub fn storeToPixels(self: *@This(), addr: Cell, value: u8) void {
        if (addr < @sizeOf(self.pixels.palette)) {
            self.pixels.palette[addr] = value;
        }
    }

    pub fn fetchFromPixels(self: *@This(), addr: Cell) u8 {
        if (addr < @sizeOf(self.pixels.palette)) {
            return self.pixels.palette[addr];
        } else {
            return 0;
        }
    }

    pub fn storeToCharacters(self: *@This(), addr: Cell, value: u8) void {
        const break0 = @sizeOf(self.characters.palette);
        const break1 = break0 + @sizeOf(self.characters.sprites);
        const break2 = break1 + @sizeOf(self.characters.buffer);
        if (addr < break0) {
            self.characters.palette[addr] = value;
        } else if (addr < break1) {
            self.characters.sprites[addr - break0] = value;
        } else if (addr < break2) {
            self.characters.buffer[addr - break1] = value;
        }
    }

    pub fn fetchFromCharacters(self: *@This(), addr: Cell) u8 {
        const break0 = @sizeOf(self.characters.palette);
        const break1 = break0 + @sizeOf(self.characters.sprites);
        const break2 = break1 + @sizeOf(self.characters.buffer);
        if (addr < break0) {
            return self.characters.palette[addr];
        } else if (addr < break1) {
            return self.characters.sprites[addr - break0];
        } else if (addr < break2) {
            return self.characters.buffer[addr - break1];
        }
    }

    // ===

    fn clearBuffer(self: *@This()) void {
        const std = @import("std");
        var xo = std.rand.Xoshiro256.init(0xdeadbeef);
        for (&self.pixels.buffer) |*pixel| {
            pixel.* = xo.random().int(u8);
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

    pub fn updateTexture(self: *@This()) void {
        c.glBindTexture(c.GL_TEXTURE_2D, self.texture);
        c.glTexSubImage2D(
            c.GL_TEXTURE_2D,
            0,
            0,
            0,
            screen_width,
            screen_height,
            c.GL_RGB,
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

const gfx = struct {
    const std = @import("std");

    const vert_shader_string = @embedFile("shaders/vert.glsl");
    const frag_shader_string = @embedFile("shaders/frag.glsl");

    const error_allocator = std.heap.c_allocator;

    const shader = struct {
        fn create(str: []const u8, shader_type: c.GLenum) c.GLuint {
            const shd = c.glCreateShader(shader_type);
            if (shd == 0) {
                // TODO error
                return 0;
            }

            const ptrs = [_]*const u8{@ptrCast(str.ptr)};
            const lens = [_]c_int{@intCast(str.len)};

            c.glShaderSource(shd, 1, &ptrs, &lens);
            c.glCompileShader(shd);

            var info_len: c_int = 0;
            c.glGetShaderiv(shd, c.GL_INFO_LOG_LENGTH, &info_len);
            if (info_len != 0) {
                const buf = error_allocator.alloc(u8, @intCast(info_len)) catch unreachable;
                c.glGetShaderInfoLog(shd, info_len, null, buf.ptr);
                std.debug.print("Shader info:\n{s}", .{buf});
                error_allocator.free(buf);
            }

            var success: c_int = undefined;
            c.glGetShaderiv(shd, c.GL_COMPILE_STATUS, &success);
            if (success != c.GL_TRUE) {
                // TODO error
                return 0;
            }
            return shd;
        }

        fn deinit(shd: c.GLuint) void {
            // TODO
            _ = shd;
        }
    };

    const program = struct {
        fn create(vert_shader: c.GLuint, frag_shader: c.GLuint) c.GLuint {
            const shaders = [_]c.GLuint{
                vert_shader,
                frag_shader,
            };
            const prog = c.glCreateProgram();
            errdefer c.glDeleteProgram(prog);

            if (prog == 0) {
                // TODO handle error
                return 0;
            }

            for (shaders) |shd| {
                c.glAttachShader(prog, shd);
            }

            c.glLinkProgram(prog);

            var info_len: c_int = 0;
            c.glGetProgramiv(prog, c.GL_INFO_LOG_LENGTH, &info_len);
            if (info_len != 0) {
                const buf = error_allocator.alloc(u8, @intCast(info_len)) catch unreachable;
                c.glGetProgramInfoLog(prog, info_len, null, buf.ptr);
                std.debug.print("Program info:\n{s}", .{buf});
                error_allocator.free(buf);
            }

            var success: c_int = undefined;
            c.glGetProgramiv(prog, c.GL_LINK_STATUS, &success);
            if (success != c.GL_TRUE) {
                // TODO handle error
                return 0;
            }

            return prog;
        }

        fn deinit(prog: c.GLuint) void {
            // TODO
            _ = prog;
        }
    };
};
