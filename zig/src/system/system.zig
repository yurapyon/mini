const c = @import("c.zig");

pub const System = struct {
    window: *c.GLFWwindow,

    pub fn init(self: *@This()) !void {
        self.window = try c.gfx.init();
        // TODO
        //   load base file
        //   find xts
    }

    pub fn deinit(_: @This()) void {
        c.gfx.deinit();
    }

    pub fn loop(self: *@This()) !void {
        while (c.glfwWindowShouldClose(self.window) == c.GL_FALSE) {
            c.glClear(c.GL_COLOR_BUFFER_BIT);
            c.glfwSwapBuffers(self.window);
            c.glfwPollEvents();
        }
    }
};
