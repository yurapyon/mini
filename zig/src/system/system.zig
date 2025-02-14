const std = @import("std");

const runtime = @import("../runtime.zig");
const Runtime = runtime.Runtime;
const Cell = runtime.Cell;
const ExternalError = runtime.ExternalError;

const externals = @import("../externals.zig");
const External = externals.External;

const dictionary = @import("../dictionary.zig");
const Dictionary = dictionary.Dictionary;

const c = @import("c.zig");

const video = @import("video.zig");
const Video = video.Video;

// ===

const window_title = "pyon vPC";

const system_file = @embedFile("system.mini.fth");

const ExternalId = enum(Cell) {
    bye = 64,
    pixel,
    read_pixel,
    palette,
    video_update,
    _max,
    _,
};

fn externalsCallback(rt: *Runtime, token: Cell, userdata: ?*anyopaque) External.Error!bool {
    const system = @as(*System, @ptrCast(@alignCast(userdata)));

    const external_id = @as(ExternalId, @enumFromInt(token));

    switch (external_id) {
        .bye => {
            // TODO
            // maybe just trigger glfw window close
        },
        .pixel => {
            // TODO order for this?
            const page = rt.data_stack.pop();
            const addr = rt.data_stack.pop();
            const color = rt.data_stack.pop();

            system.video.putPixel(
                page,
                addr,
                @truncate(color),
            );
        },
        .read_pixel => {
            // TODO
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
        .video_update => {
            system.video.updateTexture();
        },
        else => return false,
    }

    return true;
}

pub const System = struct {
    rt: *Runtime,

    xts: struct {
        frame: ?Cell,
    },

    window: *c.GLFWwindow,
    video: Video,

    // TODO
    // should_bye: bool,

    pub fn init(self: *@This(), rt: *Runtime) !void {
        self.rt = rt;

        try self.initWindow();

        self.video.init();

        try self.registerExternals(rt);

        rt.processBuffer(system_file) catch |err| switch (err) {
            error.WordNotFound => {
                std.debug.print("Word not found: {s}\n", .{
                    rt.last_evaluated_word orelse unreachable,
                });
                return err;
            },
            else => return err,
        };

        self.xts.frame = try rt.getXt("__frame");
    }

    pub fn deinit(_: @This()) void {
        c.glfwTerminate();
    }

    // ===

    fn initWindow(self: *@This()) !void {
        if (c.glfwInit() != c.GL_TRUE) {
            return error.CannotInitGLFW;
        }
        errdefer c.glfwTerminate();

        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, @intCast(3));
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, @intCast(3));
        c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
        c.glfwWindowHint(c.GLFW_RESIZABLE, c.GL_FALSE);
        c.glfwWindowHint(c.GLFW_FLOATING, c.GL_TRUE);
        // TODO
        // c.glfwWindowHint(c.GLFW_DECORATED, c.GL_FALSE);
        c.glfwSwapInterval(1);

        // note: window creation fails if we can't get the desired opengl version

        const window = c.glfwCreateWindow(
            video.screen_width * 2,
            video.screen_height * 2,
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
    }

    // ===

    fn registerExternals(self: *@This(), rt: *Runtime) !void {
        const external = External{
            .callback = externalsCallback,
            .userdata = self,
        };
        const forth_vocabulary_addr = Dictionary.forth_vocabulary_addr;
        try rt.defineExternal(
            "bye",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.bye),
        );
        try rt.defineExternal(
            "pixel",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.pixel),
        );
        try rt.defineExternal(
            "readp",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.read_pixel),
        );
        try rt.defineExternal(
            "palette",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.palette),
        );
        try rt.defineExternal(
            "v-up",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.video_update),
        );
        try rt.addExternal(external);
    }

    pub fn loop(self: *@This()) !void {
        while (c.glfwWindowShouldClose(self.window) == c.GL_FALSE) {
            c.glClear(c.GL_COLOR_BUFFER_BIT);
            self.video.draw();
            c.glfwSwapBuffers(self.window);

            c.glfwPollEvents();

            if (self.xts.frame) |fxt| {
                // TODO handle errors
                try self.rt.callXt(fxt);
            }

            std.time.sleep(30000000);
        }

        self.deinit();
    }
};
