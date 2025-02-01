const c = @cImport({
    @cInclude("GLFW/glfw3.h");

    // TODO
    // @cInclude("epoxy/gl.h");
    // @cInclude("GLFW/glfw3.h");
    // @cInclude("stb_image.h");
    // @cInclude("unistd.h");
});

pub usingnamespace c;

pub const gfx = struct {
    const vert_shader = @embedFile("shaders/vert.glsl");
    const frag_shader = @embedFile("shaders/frag.glsl");

    pub fn init() !*c.GLFWwindow {
        if (c.glfwInit() != c.GL_TRUE) {
            return error.CannotInitGLFW;
        }
        errdefer c.glfwTerminate();

        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, @intCast(3));
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, @intCast(3));
        c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
        c.glfwWindowHint(c.GLFW_RESIZABLE, c.GL_FALSE);
        c.glfwWindowHint(c.GLFW_FLOATING, c.GL_TRUE);
        c.glfwSwapInterval(1);

        // note: window creation fails if we can't get the desired opengl version

        const window = c.glfwCreateWindow(
            @intCast(512 * 2),
            @intCast(384 * 2),
            "pyon vPC",
            null,
            null,
        ) orelse return error.CannotInitWindow;
        errdefer c.glfwDestroyWindow(window);

        c.glfwMakeContextCurrent(window);

        var w: c_int = undefined;
        var h: c_int = undefined;
        c.glfwGetFramebufferSize(window, &w, &h);
        c.glViewport(0, 0, w, h);

        return window;
    }

    pub fn deinit() void {
        c.glfwTerminate();
    }

    pub const shader = struct {
        pub fn create(str: []const u8, shader_type: c.GLenum) c.GLuint {
            const shd = c.glCreateShader(shader_type);
            if (shd == 0) {
                // TODO error
                return 0;
            }

            c.glShaderSource(
                shd,
                1,
                &[_]*const u8{@ptrCast(str.ptr)},
                &[_]c_int{@intCast(str.len)},
            );
            c.glCompileShader(shd);

            var info_len: c_int = 0;
            c.glGetShaderiv(shd, c.GL_INFO_LOG_LENGTH, &info_len);
            if (info_len != 0) {
                // TODO error
                // var buf = try heap_alloc.alloc(u8, @intCast(usize, info_len));
                // glGetShaderInfoLog(shader, info_len, null, buf.ptr);
                // std.debug.print("shader info:\n{s}", .{buf});
                // heap_alloc.free(buf);
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
        pub fn create() c.GLuint {
            const vert = shader.create(vert_shader, c.GL_VERTEX_SHADER);
            const frag = shader.create(frag_shader, c.GL_FRAGMENT_SHADER);
            const shaders = [_]c.GLuint{
                vert,
                frag,
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
                // TODO handle error
                // var buf = try heap_alloc.alloc(u8, @intCast(usize, info_len));
                // glGetProgramInfoLog(program, info_len, null, buf.ptr);
                // std.debug.print("program info:\n{s}", .{buf});
                // heap_alloc.free(buf);
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

    pub const buffer = struct {
        pub fn createQuad() c.GLuint {
            var buf: c.GLuint = undefined;
            c.glGenBuffers(1, &buf);
            c.glBindBuffer(c.GL_ARRAY_BUFFER, buf);
            const data = [_]f32{
                1.0, 1.0, 1.0, 1.0,
                0.0, 1.0, 0.0, 1.0,
                1.0, 0.0, 1.0, 0.0,
                0.0, 0.0, 0.0, 0.0,
            };
            c.glBufferData(
                c.GL_ARRAY_BUFFER,
                @sizeOf(@TypeOf(data)),
                &data,
                c.GL_STATIC_DRAW,
            );
            return buf;
        }

        pub fn deinit(buf: c.GLuint) void {
            // TODO
            _ = buf;
        }
    };

    pub const texture = struct {
        pub fn createBlank(w: u32, h: u32) c.GLuint {
            var tex: c.GLuint = undefined;
            c.glGenTextures(1, &tex);
            c.glBindTexture(c.GL_TEXTURE_2D, tex);

            c.glTexImage2D(
                c.GL_TEXTURE_2D,
                0,
                c.GL_RGBA,
                @intCast(w),
                @intCast(h),
                0,
                c.GL_RGBA,
                c.GL_UNSIGNED_BYTE,
                null,
            );

            // c.glGenerateMipmap(c.GL_TEXTURE_2D);
            c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_REPEAT);
            c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_REPEAT);
            c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
            c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);

            c.glBindTexture(c.GL_TEXTURE_2D, 0);

            return tex;
        }

        pub fn setData(tex: c.GLuint, w: u32, h: u32, data: []const u8) void {
            // TODO
            _ = tex;
            _ = w;
            _ = h;
            _ = data;
        }

        pub fn deinit(tex: c.GLuint) void {
            // TODO
            _ = tex;
        }
    };
};
