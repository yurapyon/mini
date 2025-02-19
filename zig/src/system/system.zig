const std = @import("std");

const runtime = @import("../runtime.zig");
const Runtime = runtime.Runtime;
const Cell = runtime.Cell;
const ExternalError = runtime.ExternalError;

const bytecodes = @import("../bytecodes.zig");

const mem = @import("../memory.zig");

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
    bye = bytecodes.bytecodes_count,
    debug_emit,
    set_xt,
    put_pixel,
    pixels_store,
    pixels_fetch,
    characters_store,
    characters_fetch,
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
        .debug_emit => {
            // TODO dont use std.debug
            const raw_char = rt.data_stack.pop();
            const char = @as(u8, @truncate(raw_char & 0xff));
            std.debug.print("{c}", .{char});
        },
        .set_xt => {
            const id = rt.data_stack.pop();
            const addr = rt.data_stack.pop();

            const xt = if (addr == 0) null else addr;

            switch (id) {
                0 => system.xts.frame = xt,
                1 => system.xts.keydown = xt,
                2 => system.xts.mousemove = xt,
                3 => system.xts.mousedown = xt,
                else => {},
            }
        },
        .put_pixel => {
            const idx = rt.data_stack.pop();
            const y = rt.data_stack.pop();
            const x = rt.data_stack.pop();

            // TODO fit in screen w/h
            system.video.pixels.putPixel(
                x,
                y,
                @truncate(idx),
            );
        },
        .pixels_store => {
            const addr = rt.data_stack.pop();
            const value = rt.data_stack.pop();

            system.video.pixels.store(
                addr,
                @truncate(value),
            );
        },
        .pixels_fetch => {
            const addr = rt.data_stack.pop();

            const value = system.video.pixels.fetch(
                addr,
            );

            rt.data_stack.push(value);
        },
        .characters_store => {
            const addr = rt.data_stack.pop();
            const value = rt.data_stack.pop();

            system.video.characters.store(
                addr,
                @truncate(value),
            );
        },
        .characters_fetch => {
            const addr = rt.data_stack.pop();

            const value = system.video.characters.fetch(
                addr,
            );

            rt.data_stack.push(value);
        },
        .video_update => {
            system.video.update();
        },
        else => return false,
    }

    return true;
}

const glfw_callbacks = struct {
    fn key(
        win: ?*c.GLFWwindow,
        keycode: c_int,
        scancode: c_int,
        action: c_int,
        mods: c_int,
    ) callconv(.C) void {
        const system: *System = @alignCast(@ptrCast(
            c.glfwGetWindowUserPointer(win),
        ));
        _ = keycode;
        _ = scancode;
        _ = action;
        _ = mods;
        // vm.push(cintToCell(mods)) catch unreachable;
        // vm.push(cintToCell(action)) catch unreachable;
        // vm.push(cintToCell(scancode)) catch unreachable;
        // vm.push(cintToCell(key)) catch unreachable;
        if (system.xts.keydown) |ext| {
            system.rt.callXt(ext) catch unreachable;
        }
    }

    fn cursorPosition(
        win: ?*c.GLFWwindow,
        x: f64,
        y: f64,
    ) callconv(.C) void {
        const system: *System = @alignCast(@ptrCast(
            c.glfwGetWindowUserPointer(win),
        ));
        // TODO
        //   use signed cell ?
        //     probably not
        //   limit to intMax
        //   write a fn for the xy transform
        const x_float = x / 2 - (video.screen_width - 400) / 2;
        const y_float = y / 2 - (video.screen_height - 300) / 2;
        const x_cell: Cell = if (x_float < 0) 0 else @intFromFloat(x_float);
        const y_cell: Cell = if (y_float < 0) 0 else @intFromFloat(y_float);
        system.rt.data_stack.push(x_cell);
        system.rt.data_stack.push(y_cell);
        if (system.xts.mousemove) |ext| {
            system.rt.callXt(ext) catch unreachable;
        }
    }

    fn mouseButton(
        win: ?*c.GLFWwindow,
        button: c_int,
        action: c_int,
        mods: c_int,
    ) callconv(.C) void {
        const system: *System = @alignCast(@ptrCast(
            c.glfwGetWindowUserPointer(win),
        ));
        // TODO
        //   turn into forth specific structure
        // system.rt.data_stack.push(@truncate(button));
        // system.rt.data_stack.push(@truncate(action));
        // system.rt.data_stack.push(@truncate(mods));
        _ = button;
        _ = action;
        _ = mods;
        if (system.xts.mousedown) |ext| {
            system.rt.callXt(ext) catch unreachable;
        }
    }

    fn char(
        win: ?*c.GLFWwindow,
        codepoint: c_uint,
    ) callconv(.C) void {
        const system: *System = @alignCast(@ptrCast(c.glfwGetWindowUserPointer(win)));
        _ = system;
        _ = codepoint;
        // vm.push(codepoint) catch unreachable;
        // vm.execute(xts.charInput) catch unreachable;
    }

    fn windowSize(
        win: ?*c.GLFWwindow,
        width: c_int,
        height: c_int,
    ) callconv(.C) void {
        const system: *System = @alignCast(@ptrCast(c.glfwGetWindowUserPointer(win)));
        _ = system;
        _ = width;
        _ = height;
        // vm.push(cintToCell(height)) catch unreachable;
        // vm.push(cintToCell(width)) catch unreachable;
        // vm.execute(xts.windowSize) catch unreachable;
    }
};

pub const System = struct {
    rt: *Runtime,

    xts: struct {
        frame: ?Cell,
        keydown: ?Cell,
        mousemove: ?Cell,
        mousedown: ?Cell,
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

        self.xts.frame = null;
        self.xts.keydown = null;
        self.xts.mousemove = null;
        self.xts.mousedown = null;

        c.glEnable(c.GL_BLEND);
        c.glBlendEquation(c.GL_FUNC_ADD);
        c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
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
        // focus on open
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

        c.glfwSetWindowUserPointer(window, self);
        _ = c.glfwSetKeyCallback(window, glfw_callbacks.key);
        _ = c.glfwSetCursorPosCallback(window, glfw_callbacks.cursorPosition);
        _ = c.glfwSetMouseButtonCallback(window, glfw_callbacks.mouseButton);

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
            "__emit",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.debug_emit),
        );
        try rt.defineExternal(
            "sysxt!",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.set_xt),
        );
        try rt.defineExternal(
            "putp",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.put_pixel),
        );
        try rt.defineExternal(
            "pixels!",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.pixels_store),
        );
        try rt.defineExternal(
            "pixels@",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.pixels_fetch),
        );
        try rt.defineExternal(
            "characters!",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.characters_store),
        );
        try rt.defineExternal(
            "characters@",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.characters_fetch),
        );
        try rt.defineExternal(
            // TODO rename
            "v-up",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.video_update),
        );
        try rt.addExternal(external);
    }

    pub fn loop(self: *@This()) !void {
        while (c.glfwWindowShouldClose(self.window) == c.GL_FALSE) {
            self.video.draw();

            c.glfwSwapBuffers(self.window);

            c.glfwPollEvents();

            if (self.xts.frame) |fxt| {
                // TODO handle errors
                try self.rt.callXt(fxt);
            }

            std.time.sleep(30_000_000);
        }

        self.deinit();
    }
};
