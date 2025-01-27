const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub usingnamespace c;

pub const gfx = struct {
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
