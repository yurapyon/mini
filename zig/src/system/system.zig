const std = @import("std");

const runtime = @import("../runtime.zig");
const Runtime = runtime.Runtime;
const Cell = runtime.Cell;
const ExternalError = runtime.ExternalError;

const externals = @import("../externals.zig");
const External = externals.External;

const c = @import("c.zig");
const Video = @import("video.zig").Video;
const Storage = @import("storage.zig").Storage;

// ===

const ExternalId = enum(Cell) {
    bye = 64,
    putc,
    diskStore,
    diskFetch,
    _,
};

const system_file = @embedFile("system.mini.fth");

fn externalsCallback(rt: *Runtime, token: Cell, userdata: ?*anyopaque) External.Error!bool {
    _ = rt;
    _ = token;
    _ = userdata;
}

pub const System = struct {
    window: *c.GLFWwindow,

    // devices
    video: Video,
    storage: Storage,

    pub fn init(self: *@This(), rt: *Runtime) !void {
        self.window = try c.gfx.init();
        self.video.init();
        self.storage.init();
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
