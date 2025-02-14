const c = @import("c.zig");

const runtime = @import("../runtime.zig");
const Cell = runtime.Cell;

// ===

// 64k * 3 can max 512 x 384 x 8bit
const page_size = 64 * 1024;
const page_ct = 3;

pub const screen_width = 512;
pub const screen_height = 384;

// 256 color palette with 24bit color
const RGB = [3]u8;

pub const Video = struct {
    buffer: [page_size * page_ct]RGB,
    palette: [256]RGB,

    texture: c.GLuint,
    vbo: c.GLuint,
    vao: c.GLuint,
    program: c.GLuint,

    pub fn init(self: *@This()) void {
        self.makeTexture();
        self.makeQuad();
        self.makeProgram();

        const tex_location = c.glGetUniformLocation(self.program, "diffuse");
        c.glUseProgram(self.program);
        c.glBindTexture(c.GL_TEXTURE_2D, self.texture);
        c.glActiveTexture(c.GL_TEXTURE0);
        c.glUniform1i(tex_location, 0);

        self.clearBuffer();
        self.updateTexture();

        //   init default palette
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

    // ===

    fn clearBuffer(self: *@This()) void {
        for (&self.buffer) |*pixel| {
            pixel[0] = 0;
            pixel[1] = 0;
            pixel[2] = 255;
        }
    }

    pub fn putPixel(
        self: *@This(),
        page: Cell,
        addr: Cell,
        palette_idx: u8,
    ) void {
        const color = &self.palette[palette_idx];
        const page_at = page % page_ct;
        const buffer_at = @as(usize, page_at) * page_size + addr;
        const buffer_color = self.buffer[buffer_at][0..3];
        @memcpy(buffer_color, color);
    }

    pub fn setPalette(
        self: *@This(),
        at: u8,
        r: u8,
        g: u8,
        b: u8,
    ) void {
        self.palette[at][0] = r;
        self.palette[at][1] = g;
        self.palette[at][2] = b;
    }

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
            &self.buffer,
        );
    }

    pub fn draw(self: *@This()) void {
        c.glUseProgram(self.program);
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
