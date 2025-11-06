const std = @import("std");

pub const c = @cImport({
    @cInclude("GLFW/glfw3.h");
    @cInclude("OpenGL/gl3.h");
    @cInclude("stb_image.h");

    // TODO
    // @cInclude("epoxy/gl.h");
    // @cInclude("GLFW/glfw3.h");
    // @cInclude("unistd.h");
});

pub const gfx = struct {
    const error_allocator = std.heap.c_allocator;

    pub const shader = struct {
        pub fn create(str: []const u8, shader_type: c.GLenum) c.GLuint {
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
                const buf = error_allocator.alloc(
                    u8,
                    @intCast(info_len),
                ) catch unreachable;
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

        pub fn deinit(shd: c.GLuint) void {
            // TODO
            _ = shd;
        }
    };

    pub const program = struct {
        pub fn create(vert_shader: c.GLuint, frag_shader: c.GLuint) c.GLuint {
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
                const buf = error_allocator.alloc(
                    u8,
                    @intCast(info_len),
                ) catch unreachable;
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

        pub fn deinit(prog: c.GLuint) void {
            // TODO
            _ = prog;
        }
    };

    pub const texture = struct {
        pub fn createEmpty(
            width: c_int,
            height: c_int,
        ) c.GLuint {
            var tex: c.GLuint = undefined;
            c.glGenTextures(1, &tex);
            c.glBindTexture(c.GL_TEXTURE_2D, tex);

            c.glTexImage2D(
                c.GL_TEXTURE_2D,
                0,
                c.GL_RGB,
                width,
                height,
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

            return tex;
        }
    };

    pub const buffer = struct {
        pub fn create() c.GLuint {
            var vbo: c.GLuint = undefined;
            c.glGenBuffers(1, &vbo);
            return vbo;
        }
    };

    pub const vertex_array = struct {
        pub fn create() c.GLuint {
            var vao: c.GLuint = undefined;
            c.glGenVertexArrays(1, &vao);
            return vao;
        }
    };
};
