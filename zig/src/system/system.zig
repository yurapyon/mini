const std = @import("std");

const kernel = @import("../kernel.zig");
const Kernel = kernel.Kernel;
const Cell = kernel.Cell;

const externals = @import("../externals.zig");
const External = externals.External;

const c = @import("c.zig").c;

const video = @import("video.zig");
const Video = video.Video;

// ===

const window_title = "pyon vPC";

const system_file = @embedFile("system.mini.fth");

const glfw_callbacks = struct {
    fn key(
        win: ?*c.GLFWwindow,
        keycode: c_int,
        scancode: c_int,
        action: c_int,
        mods: c_int,
    ) callconv(.c) void {
        const system: *System = @ptrCast(@alignCast(
            c.glfwGetWindowUserPointer(win),
        ));
        // TODO
        _ = scancode;
        _ = mods;
        if (system.xts.key) |xt| {
            system.k.data_stack.pushCell(@intCast(keycode));
            system.k.data_stack.pushCell(@intCast(action));
            // TODO error
            system.k.callXt(xt) catch unreachable;
        }
    }

    fn cursorPosition(
        win: ?*c.GLFWwindow,
        x: f64,
        y: f64,
    ) callconv(.c) void {
        const system: *System = @ptrCast(@alignCast(
            c.glfwGetWindowUserPointer(win),
        ));
        // TODO
        //   use signed cell ?
        //     probably not
        //   limit to intMax
        //   write a fn for the xy transform
        if (system.xts.mousemove) |xt| {
            // const x_float = x / 2 - (video.screen_width - 400) / 2;
            // const y_float = y / 2 - (video.screen_height - 300) / 2;
            const x_float = x / 2;
            const y_float = y / 2;
            const x_cell: Cell = if (x_float < 0) 0 else @intFromFloat(x_float);
            const y_cell: Cell = if (y_float < 0) 0 else @intFromFloat(y_float);
            system.k.data_stack.pushCell(x_cell);
            system.k.data_stack.pushCell(y_cell);
            system.k.callXt(xt) catch unreachable;
        }
    }

    fn mouseButton(
        win: ?*c.GLFWwindow,
        button: c_int,
        action: c_int,
        mods: c_int,
    ) callconv(.c) void {
        const system: *System = @ptrCast(@alignCast(
            c.glfwGetWindowUserPointer(win),
        ));
        if (system.xts.mousedown) |xt| {
            var value = @as(Cell, @intCast(button)) & 0x7;
            if (action == c.GLFW_PRESS) {
                value |= 0x10;
            }
            system.k.data_stack.pushCell(value);
            system.k.data_stack.pushCell(@intCast(mods));
            system.k.callXt(xt) catch unreachable;
        }
    }

    fn char(
        win: ?*c.GLFWwindow,
        codepoint: c_uint,
    ) callconv(.c) void {
        const system: *System = @ptrCast(@alignCast(c.glfwGetWindowUserPointer(win)));
        if (system.xts.char) |xt| {
            const high: Cell = @intCast((codepoint & 0xff00) >> 16);
            const low: Cell = @intCast(codepoint & 0xff);
            system.k.data_stack.pushCell(high);
            system.k.data_stack.pushCell(low);
            system.k.callXt(xt) catch unreachable;
        }
    }

    fn windowSize(
        win: ?*c.GLFWwindow,
        width: c_int,
        height: c_int,
    ) callconv(.c) void {
        const system: *System = @ptrCast(@alignCast(c.glfwGetWindowUserPointer(win)));
        _ = system;
        _ = width;
        _ = height;
        // vm.push(cintToCell(height)) catch unreachable;
        // vm.push(cintToCell(width)) catch unreachable;
        // vm.execute(xts.windowSize) catch unreachable;
    }
};

const exts = struct {
    fn setXt(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const idx = k.data_stack.popCell();
        const addr = k.data_stack.popCell();

        const xt = if (addr == 0) null else addr;

        switch (idx) {
            0 => s.xts.key = xt,
            1 => s.xts.mousemove = xt,
            2 => s.xts.mousedown = xt,
            3 => s.xts.char = xt,
            else => {},
        }
    }

    fn shouldClose(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const should_close = c.glfwWindowShouldClose(s.window) == c.GL_TRUE;
        k.data_stack.pushBoolean(should_close);
    }

    fn drawPoll(_: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        s.video.update();
        s.video.draw();
        c.glfwSwapBuffers(s.window);
        c.glfwPollEvents();

        std.Thread.sleep(30_000_000);
        // std.Thread.sleep(100_000_000);
    }

    fn deinit(_: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));
        s.deinit();
    }

    fn pixelPaletteStore(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const addr = k.data_stack.popCell();
        const value = k.data_stack.popCell();

        s.video.pixels.storePalette(addr, @truncate(value));
    }

    fn pixelPaletteFetch(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const addr = k.data_stack.popCell();

        const value = s.video.pixels.fetchPalette(addr);

        k.data_stack.pushCell(value);
    }

    fn pixelSet(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const idx = k.data_stack.popCell();
        const y = k.data_stack.popCell();
        const x = k.data_stack.popCell();

        // TODO fit in screen w/h
        s.video.pixels.putPixel(x, y, @truncate(idx));
    }

    fn pixelLine(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const idx = k.data_stack.popCell();
        const y1 = k.data_stack.popCell();
        const x1 = k.data_stack.popCell();
        const y0 = k.data_stack.popCell();
        const x0 = k.data_stack.popCell();

        // TODO fit in screen w/h
        s.video.pixels.putLine(x0, y0, x1, y1, @truncate(idx));
    }

    fn pixelRect(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const idx = k.data_stack.popCell();
        const y1 = k.data_stack.popCell();
        const x1 = k.data_stack.popCell();
        const y0 = k.data_stack.popCell();
        const x0 = k.data_stack.popCell();

        // TODO fit in screen w/h
        s.video.pixels.putRect(x0, y0, x1, y1, @truncate(idx));
    }

    fn brushSet(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const idx = k.data_stack.popCell();
        const y = k.data_stack.popCell();
        const x = k.data_stack.popCell();

        // TODO fit in screen w/h
        s.video.pixels.putBrush(x, y, @truncate(idx));
    }

    fn brushStore(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const addr = k.data_stack.popCell();
        const value = k.data_stack.popCell();

        s.video.pixels.storeBrush(addr, @truncate(value));
    }

    fn brushFetch(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const addr = k.data_stack.popCell();

        const value = s.video.pixels.fetchBrush(addr);

        k.data_stack.pushCell(value);
    }

    fn brushLine(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const idx = k.data_stack.popCell();
        const y1 = k.data_stack.popCell();
        const x1 = k.data_stack.popCell();
        const y0 = k.data_stack.popCell();
        const x0 = k.data_stack.popCell();

        // TODO fit in screen w/h
        s.video.pixels.putBrushLine(x0, y0, x1, y1, @truncate(idx));
    }
};

pub const System = struct {
    k: *Kernel,

    xts: struct {
        key: ?Cell,
        mousemove: ?Cell,
        mousedown: ?Cell,
        char: ?Cell,
    },

    window: *c.GLFWwindow,
    video: Video,

    // TODO
    // should_bye: bool,

    pub fn init(self: *@This(), k: *Kernel) !void {
        self.k = k;

        try self.initWindow();

        // TODO allow for different allocator than the kernels
        self.video.init(k.allocator);

        self.xts.key = null;
        self.xts.mousemove = null;
        self.xts.mousedown = null;
        self.xts.char = null;

        c.glEnable(c.GL_BLEND);
        c.glBlendEquation(c.GL_FUNC_ADD);
        c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

        try self.registerExternals(k);

        try k.setAcceptBuffer(system_file);
        k.initForth();
        try k.execute();
    }

    pub fn deinit(self: *@This()) void {
        self.video.deinit();
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
        _ = c.glfwSetCharCallback(window, glfw_callbacks.char);

        self.window = window;
    }

    fn registerExternals(self: *@This(), k: *Kernel) !void {
        try k.addExternal("setxt", .{
            .callback = exts.setXt,
            .userdata = self,
        });
        try k.addExternal("close?", .{
            .callback = exts.shouldClose,
            .userdata = self,
        });
        try k.addExternal("draw/poll", .{
            .callback = exts.drawPoll,
            .userdata = self,
        });
        try k.addExternal("deinit", .{
            .callback = exts.deinit,
            .userdata = self,
        });
        try k.addExternal("pcolors!", .{
            .callback = exts.pixelPaletteStore,
            .userdata = self,
        });
        try k.addExternal("pcolors@", .{
            .callback = exts.pixelPaletteFetch,
            .userdata = self,
        });
        try k.addExternal("pset", .{
            .callback = exts.pixelSet,
            .userdata = self,
        });
        try k.addExternal("pline", .{
            .callback = exts.pixelLine,
            .userdata = self,
        });
        try k.addExternal("prect", .{
            .callback = exts.pixelRect,
            .userdata = self,
        });
        try k.addExternal("pbrush!", .{
            .callback = exts.brushStore,
            .userdata = self,
        });
        try k.addExternal("pbrush@", .{
            .callback = exts.brushFetch,
            .userdata = self,
        });
        try k.addExternal("pbrush", .{
            .callback = exts.brushSet,
            .userdata = self,
        });
        try k.addExternal("pbrushline", .{
            .callback = exts.brushLine,
            .userdata = self,
        });
    }
};
