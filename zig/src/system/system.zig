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
    // main/glfw ===

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

    // video ===

    fn getImageIds(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));
        k.data_stack.pushCell(s.video.handles.screen);
        k.data_stack.pushCell(s.video.handles.characters);
    }

    fn paletteStore(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const addr = k.data_stack.popCell();
        const value = k.data_stack.popCell();

        if (addr & 0x8000 > 0) {
            const masked_addr = addr & 0x7fff;
            s.video.characters.paletteStore(masked_addr, @truncate(value));
        } else {
            s.video.pixels.paletteStore(addr, @truncate(value));
        }
    }

    fn paletteFetch(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const addr = k.data_stack.popCell();

        const value = if (addr & 0x8000 > 0)
            s.video.characters.paletteFetch(addr & 0x7fff)
        else
            s.video.pixels.paletteFetch(addr);

        k.data_stack.pushCell(value);
    }

    fn createImage(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const height = k.data_stack.popCell();
        const width = k.data_stack.popCell();
        const id = s.video.createImage(
            width,
            height,
        ) catch return error.ExternalPanic;

        k.data_stack.pushCell(id);
    }

    fn freeImage(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const id = k.data_stack.popCell();

        s.video.freeImage(id);
    }

    // TODO all image editing should probably use signed cells

    fn imagePutXY(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const image_id = k.data_stack.popCell();
        const color = k.data_stack.popCell();
        const y = k.data_stack.popCell();
        const x = k.data_stack.popCell();

        const image = s.video.getImage(image_id);

        image.putXY(@intCast(x), @intCast(y), @truncate(color));
    }

    fn imagePutLine(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const image_id = k.data_stack.popCell();
        const color = k.data_stack.popCell();
        const y1 = k.data_stack.popCell();
        const x1 = k.data_stack.popCell();
        const y0 = k.data_stack.popCell();
        const x0 = k.data_stack.popCell();

        const image = s.video.getImage(image_id);

        image.putLine(
            @intCast(x0),
            @intCast(y0),
            @intCast(x1),
            @intCast(y1),
            @truncate(color),
        );
    }

    fn imagePutRect(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const image_id = k.data_stack.popCell();
        const color = k.data_stack.popCell();
        const y1 = k.data_stack.popCell();
        const x1 = k.data_stack.popCell();
        const y0 = k.data_stack.popCell();
        const x0 = k.data_stack.popCell();

        const image = s.video.getImage(image_id);

        image.putRect(
            @intCast(x0),
            @intCast(y0),
            @intCast(x1),
            @intCast(y1),
            @truncate(color),
        );
    }

    fn imageBlit(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const image_id = k.data_stack.popCell();
        const other_id = k.data_stack.popCell();
        const transparent = k.data_stack.popCell();
        const y = k.data_stack.popCell();
        const x = k.data_stack.popCell();

        // TODO handle errors on image not found
        const image = s.video.getImage(image_id);
        const other = s.video.getImage(other_id);

        image.blitXY(
            other.*,
            @truncate(transparent),
            @intCast(x),
            @intCast(y),
        );
    }

    fn imageBlitLine(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const image_id = k.data_stack.popCell();
        const other_id = k.data_stack.popCell();
        const transparent = k.data_stack.popCell();
        const y1 = k.data_stack.popCell();
        const x1 = k.data_stack.popCell();
        const y0 = k.data_stack.popCell();
        const x0 = k.data_stack.popCell();

        const image = s.video.getImage(image_id);
        const other = s.video.getImage(other_id);

        image.blitLine(
            other.*,
            @truncate(transparent),
            @intCast(x0),
            @intCast(y0),
            @intCast(x1),
            @intCast(y1),
        );
    }

    // ===

    fn charsStore(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const addr = k.data_stack.popCell();
        const value = k.data_stack.popCell();

        s.video.characters.store(addr, @truncate(value));
    }

    fn charsFetch(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const addr = k.data_stack.popCell();

        const value = s.video.characters.fetch(addr);

        k.data_stack.pushCell(value);
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
        try self.video.init(k.allocator);

        self.xts.key = null;
        self.xts.mousemove = null;
        self.xts.mousedown = null;
        self.xts.char = null;

        c.glEnable(c.GL_BLEND);
        c.glBlendEquation(c.GL_FUNC_ADD);
        c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

        try self.registerExternals(k);

        std.debug.print("pyon vPC\n", .{});
        try k.evaluate(system_file);
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
        try k.addExternal("image-ids", .{
            .callback = exts.getImageIds,
            .userdata = self,
        });
        try k.addExternal("p!", .{
            .callback = exts.paletteStore,
            .userdata = self,
        });
        try k.addExternal("p@", .{
            .callback = exts.paletteFetch,
            .userdata = self,
        });
        try k.addExternal("ialloc", .{
            .callback = exts.createImage,
            .userdata = self,
        });
        try k.addExternal("ifree", .{
            .callback = exts.freeImage,
            .userdata = self,
        });
        try k.addExternal("i!xy", .{
            .callback = exts.imagePutXY,
            .userdata = self,
        });
        try k.addExternal("i!line", .{
            .callback = exts.imagePutLine,
            .userdata = self,
        });
        try k.addExternal("i!rect", .{
            .callback = exts.imagePutRect,
            .userdata = self,
        });
        try k.addExternal("i!blit", .{
            .callback = exts.imageBlit,
            .userdata = self,
        });
        try k.addExternal("i!blitline", .{
            .callback = exts.imageBlitLine,
            .userdata = self,
        });
        try k.addExternal("chars!", .{
            .callback = exts.charsStore,
            .userdata = self,
        });
        try k.addExternal("chars@", .{
            .callback = exts.charsFetch,
            .userdata = self,
        });
    }
};
