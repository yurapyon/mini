const std = @import("std");

const runtime = @import("../runtime.zig");
const Runtime = runtime.Runtime;
const Cell = runtime.Cell;
const ExternalError = runtime.ExternalError;

const externals = @import("../externals.zig");
const External = externals.External;

const c = @import("c.zig");

const video = @import("video.zig");
const Video = video.Video;

// ===

const window_title = "pyon vPC";

const ExternalId = enum(Cell) {
    bye = 64,
    pixel,
    palette,
    _,
};

const system_file = @embedFile("system.mini.fth");

fn externalsCallback(rt: *Runtime, token: Cell, userdata: ?*anyopaque) External.Error!bool {
    const system = @as(*System, @ptrCast(@alignCast(userdata)));

    const external_id = @as(ExternalId, @enumFromInt(token));

    switch (external_id) {
        .bye => {
            // TODO
            // maybe just trigger glfw window close
        },
        .pixel => {
            const page = rt.data_stack.pop();
            const addr = rt.data_stack.pop();
            const color = rt.data_stack.pop();

            system.video.putPixel(
                page,
                addr,
                @truncate(color),
            );
        },
        .palette => {
            const at = rt.data_stack.pop();
            const b = rt.data_stack.pop();
            const g = rt.data_stack.pop();
            const r = rt.data_stack.pop();

            system.video.setPalette(
                @truncate(at),
                @truncate(r),
                @truncate(g),
                @truncate(b),
            );
        },
        else => {},
    }
}

pub const System = struct {
    window: *c.GLFWwindow,

    // TODO
    // should_bye: bool,

    // devices
    video: Video,

    pub fn init(self: *@This(), rt: *Runtime) !void {
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
            video.width * 2,
            video.height * 2,
            window_title,
            null,
            null,
        ) orelse return error.CannotInitWindow;
        errdefer c.glfwDestroyWindow(window);

        c.glfwMakeContextCurrent(window);

        var w: c_int = undefined;
        var h: c_int = undefined;
        c.glfwGetFramebufferSize(window, &w, &h);
        c.glViewport(0, 0, w, h);

        self.window = window;

        self.video.init();

        rt.processBuffer(system_file) catch |err| switch (err) {
            error.WordNotFound => {
                std.debug.print("Word not found: {s}\n", .{
                    rt.last_evaluated_word orelse unreachable,
                });
                return err;
            },
            else => return err,
        };
        //   find xts and store
    }

    pub fn deinit(_: @This()) void {
        c.glfwTerminate();
    }

    pub fn loop(self: *@This()) !void {
        while (c.glfwWindowShouldClose(self.window) == c.GL_FALSE) {
            c.glClear(c.GL_COLOR_BUFFER_BIT);
            self.video.draw();
            c.glfwSwapBuffers(self.window);

            c.glfwPollEvents();

            // TODO
            // std.time.sleep(33000);
        }

        self.deinit();
    }
};
