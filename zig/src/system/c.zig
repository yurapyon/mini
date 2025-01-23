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
            @intCast(800),
            @intCast(600),
            "pyon",
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
};
