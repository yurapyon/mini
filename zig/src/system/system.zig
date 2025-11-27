const std = @import("std");
const Mutex = std.Thread.Mutex;
const Semaphore = std.Thread.Semaphore;

const kernel = @import("../kernel.zig");
const Kernel = kernel.Kernel;
const Cell = kernel.Cell;
const SignedCell = kernel.SignedCell;

const externals = @import("../externals.zig");
const External = externals.External;

const c = @import("c.zig").c;

const resource_manager = @import("resource-manager.zig");
const Resource = resource_manager.Resource;
const ResourceManager = resource_manager.ResourceManager;

const input_event = @import("input-event.zig");
const InputEventTag = input_event.InputEventTag;
const InputChannel = input_event.InputChannel;

const Pixels = @import("pixels.zig").Pixels;
const Characters = @import("characters.zig").Characters;
const Image = @import("image.zig").Image;

const gamepad = @import("gamepad.zig");

// ===

// Multithreading strategy
// There need to be 3 different threads
//   1. Forth kernel
//   2. Graphics
//   3. Audio
// An easy way to handle thread-safety is:
//   1. Graphics->Forth, All GLFW events are put into a queue for Forth to poll
//   2. Forth->Graphics, video_mutex has to be locked/unlocked as needed

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

        system.input_channel.push(.{
            .key = .{
                .keycode = keycode,
                .scancode = scancode,
                .action = action,
                .mods = mods,
            },
        });
    }

    fn cursorPosition(
        win: ?*c.GLFWwindow,
        x: f64,
        y: f64,
    ) callconv(.c) void {
        const system: *System = @ptrCast(@alignCast(
            c.glfwGetWindowUserPointer(win),
        ));

        system.input_channel.push(.{
            .mouse_position = .{
                .x = x,
                .y = y,
            },
        });
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

        system.input_channel.push(.{
            .mouse_button = .{
                .button = button,
                .action = action,
                .mods = mods,
            },
        });
    }

    fn char(
        win: ?*c.GLFWwindow,
        codepoint: c_uint,
    ) callconv(.c) void {
        const system: *System = @ptrCast(@alignCast(
            c.glfwGetWindowUserPointer(win),
        ));

        system.input_channel.push(.{
            .char = .{
                .codepoint = codepoint,
            },
        });
    }

    var hacky_window_pointer_for_joysticks: ?*c.GLFWwindow = null;

    fn joystick(
        index: c_int,
        event: c_int,
    ) callconv(.c) void {
        const system: *System = @ptrCast(@alignCast(
            c.glfwGetWindowUserPointer(hacky_window_pointer_for_joysticks),
        ));

        // TODO
        // This assumes 'event' can only be connected/disconnected which may not be the case
        const is_connected = event == c.GLFW_CONNECTED;
        const is_joystick_gamepad = c.glfwJoystickIsGamepad(index) == c.GLFW_TRUE;
        gamepad.onConnectionChange(@intCast(index), is_connected and is_joystick_gamepad);

        system.input_channel.push(.{
            .gamepad_connection = .{
                .index = @intCast(index),
                .is_connected = is_connected,
            },
        });
    }
};

const exts = struct {
    // main/glfw ===

    fn poll(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const event = s.input_channel.pop();
        if (event) |ev| {
            switch (ev) {
                .close => {},
                .key => |data| {
                    // TODO
                    //   handle scancode and mods
                    //   probably push keycode first, then action
                    k.data_stack.pushCell(@intCast(data.keycode));
                    k.data_stack.pushCell(@intCast(data.action));
                },
                .mouse_position => |data| {
                    const x_float = data.x / 2;
                    const y_float = data.y / 2;
                    // TODO
                    //   use a signed cell ?
                    //   limit to intMax
                    //   write a fn for the xy transform that takes into account video scale
                    const x_cell: Cell = if (x_float < 0) 0 else @intFromFloat(x_float);
                    const y_cell: Cell = if (y_float < 0) 0 else @intFromFloat(y_float);
                    k.data_stack.pushCell(x_cell);
                    k.data_stack.pushCell(y_cell);
                },
                .mouse_button => |data| {
                    // TODO this api isn't great
                    var value = @as(Cell, @intCast(data.button)) & 0x7;
                    if (data.action == c.GLFW_PRESS) {
                        value |= 0x10;
                    }
                    k.data_stack.pushCell(value);
                    k.data_stack.pushCell(@intCast(data.mods));
                },
                .char => |data| {
                    const high: Cell = @intCast((data.codepoint & 0xff00) >> 16);
                    const low: Cell = @intCast(data.codepoint & 0xff);
                    k.data_stack.pushCell(high);
                    k.data_stack.pushCell(low);
                },
                .gamepad => |data| {
                    k.data_stack.pushSignedCell(@intCast(data.action));
                    k.data_stack.pushCell(@intCast(data.button));
                    k.data_stack.pushCell(@intCast(data.index));
                },
                .gamepad_connection => |data| {
                    k.data_stack.pushBoolean(data.is_connected);
                    k.data_stack.pushCell(@intCast(data.index));
                },
            }
            const event_type = @intFromEnum(ev);
            k.data_stack.pushCell(event_type);
            k.data_stack.pushBoolean(true);
        } else {
            k.data_stack.pushBoolean(false);
        }
    }

    fn deinit(_: *Kernel, userdata: ?*anyopaque) External.Error!void {
        // TODO
        // close the system somehow
        const s: *System = @ptrCast(@alignCast(userdata));
        _ = s;
    }

    // video ===

    fn videoLock(_: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));
        s.video_mutex.lock();
    }

    fn videoTryLock(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));
        const was_locked = s.video_mutex.tryLock();

        k.data_stack.pushBoolean(was_locked);
    }

    fn videoUnlock(_: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));
        s.video_mutex.unlock();
    }

    // TODO this could just get called after system is initialized
    fn getImageIds(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));
        k.data_stack.pushCell(s.resources.screen.handle);
        k.data_stack.pushCell(s.resources.characters.handle);
    }

    fn paletteStore(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const addr = k.data_stack.popCell();
        const value = k.data_stack.popCell();

        if (addr & 0x8000 > 0) {
            const masked_addr = addr & 0x7fff;
            s.characters.paletteStore(masked_addr, @truncate(value));
        } else {
            s.pixels.paletteStore(addr, @truncate(value));
        }
    }

    fn paletteFetch(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const addr = k.data_stack.popCell();

        const value = if (addr & 0x8000 > 0)
            s.characters.paletteFetch(addr & 0x7fff)
        else
            s.pixels.paletteFetch(addr);

        k.data_stack.pushCell(value);
    }

    fn createTimer(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const id = s.resource_manager.createTimer() catch return error.ExternalPanic;

        k.data_stack.pushCell(id);
    }

    fn freeTimer(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const id = k.data_stack.popCell();

        // TODO
        _ = id;
        _ = s;
    }

    fn setTimer(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const timer_id = k.data_stack.popCell();
        const fraction = k.data_stack.popCell();
        const seconds = k.data_stack.popCell();

        const timer = s.resource_manager.getTimer(timer_id) catch
            return error.ExternalPanic;

        const f64_seconds: f64 = @floatFromInt(seconds);
        const f64_fraction: f64 = @as(f64, @floatFromInt(fraction)) / 65536;
        const limit = f64_seconds + f64_fraction;

        timer.limit = limit;
    }

    fn checkTimer(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const timer_id = k.data_stack.popCell();

        const timer = s.resource_manager.getTimer(timer_id) catch
            return error.ExternalPanic;

        // NOTE
        // glfwGetTime can be called from any thread
        // This doesn't need to be made threadsafe unless glfwSetTime is being used somewhere
        const ct = timer.update(c.glfwGetTime());

        k.data_stack.pushCell(@truncate(ct));
    }

    fn createImage(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const height = k.data_stack.popCell();
        const width = k.data_stack.popCell();
        const id = s.resource_manager.createImage(
            width,
            height,
        ) catch return error.ExternalPanic;

        k.data_stack.pushCell(id);
    }

    fn freeImage(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const id = k.data_stack.popCell();

        // TODO
        _ = id;
        _ = s;
    }

    fn imageSetMask(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const image_id = k.data_stack.popCell();
        const use_mask = k.data_stack.popBoolean();
        const y1 = k.data_stack.popSignedCell();
        const x1 = k.data_stack.popSignedCell();
        const y0 = k.data_stack.popSignedCell();
        const x0 = k.data_stack.popSignedCell();

        const image = s.resource_manager.getImage(image_id) catch
            return error.ExternalPanic;

        image.use_mask = use_mask;
        image.mask.x0 = @intCast(x0);
        image.mask.y0 = @intCast(y0);
        image.mask.x1 = @intCast(x1);
        image.mask.y1 = @intCast(y1);
    }

    fn imageFill(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const image_id = k.data_stack.popCell();
        const color = k.data_stack.popCell();

        const image = s.resource_manager.getImage(image_id) catch
            return error.ExternalPanic;

        image.fill(@truncate(color));
    }

    fn imageRandomize(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const image_id = k.data_stack.popCell();

        const image = s.resource_manager.getImage(image_id) catch
            return error.ExternalPanic;

        image.randomize(16);
    }

    fn imagePutXY(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const image_id = k.data_stack.popCell();
        const color = k.data_stack.popCell();
        const y = k.data_stack.popSignedCell();
        const x = k.data_stack.popSignedCell();

        const image = s.resource_manager.getImage(image_id) catch
            return error.ExternalPanic;

        image.putXY(@intCast(x), @intCast(y), @truncate(color));
    }

    fn imagePutLine(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const image_id = k.data_stack.popCell();
        const color = k.data_stack.popCell();
        const y1 = k.data_stack.popSignedCell();
        const x1 = k.data_stack.popSignedCell();
        const y0 = k.data_stack.popSignedCell();
        const x0 = k.data_stack.popSignedCell();

        const image = s.resource_manager.getImage(image_id) catch
            return error.ExternalPanic;

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
        const y1 = k.data_stack.popSignedCell();
        const x1 = k.data_stack.popSignedCell();
        const y0 = k.data_stack.popSignedCell();
        const x0 = k.data_stack.popSignedCell();

        const image = s.resource_manager.getImage(image_id) catch
            return error.ExternalPanic;

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
        const y = k.data_stack.popSignedCell();
        const x = k.data_stack.popSignedCell();

        const image = s.resource_manager.getImage(image_id) catch
            return error.ExternalPanic;
        const other = s.resource_manager.getImage(other_id) catch
            return error.ExternalPanic;

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
        const y1 = k.data_stack.popSignedCell();
        const x1 = k.data_stack.popSignedCell();
        const y0 = k.data_stack.popSignedCell();
        const x0 = k.data_stack.popSignedCell();

        const image = s.resource_manager.getImage(image_id) catch
            return error.ExternalPanic;
        const other = s.resource_manager.getImage(other_id) catch
            return error.ExternalPanic;

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

        s.characters.store(addr, @truncate(value));
    }

    fn charsFetch(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const s: *System = @ptrCast(@alignCast(userdata));

        const addr = k.data_stack.popCell();

        const value = s.characters.fetch(addr);

        k.data_stack.pushCell(value);
    }
};

const ResourceAndHandle = struct {
    resource: Resource,
    handle: Cell,
};

pub const screen_width = 640;
pub const screen_height = 400;

pub const System = struct {
    k: *Kernel,

    window: *c.GLFWwindow,

    // NOTE
    // writer: Graphics thread
    // reader: Forth thread
    input_channel: InputChannel,
    video_mutex: Mutex,
    startup_semaphore: Semaphore,

    pixels: Pixels,
    characters: Characters,

    resources: struct {
        screen: ResourceAndHandle,
        characters: ResourceAndHandle,
    },

    resource_manager: ResourceManager,

    // TODO allow for different allocator than the kernels
    pub fn init(self: *@This(), k: *Kernel) !void {
        self.k = k;

        try self.input_channel.init(k.allocator);
        self.video_mutex = .{};
        self.startup_semaphore = .{};

        try self.resource_manager.init(k.allocator, &k.handles);

        try self.registerExternals(k);
        try k.evaluate(system_file);
    }

    pub fn deinit(self: *@This()) void {
        self.resource_manager.deinit();
        self.input_channel.deinit();
    }

    // ===

    fn initWindow(self: *@This()) !void {
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
            screen_width * 2,
            screen_height * 2,
            window_title,
            null,
            null,
        ) orelse return error.CannotInitWindow;
        errdefer c.glfwDestroyWindow(window);

        self.window = window;

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

        glfw_callbacks.hacky_window_pointer_for_joysticks = window;
        _ = c.glfwSetJoystickCallback(glfw_callbacks.joystick);

        c.glEnable(c.GL_BLEND);
        c.glBlendEquation(c.GL_FUNC_ADD);
        c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
    }

    pub fn run(self: *@This()) !void {
        if (c.glfwInit() != c.GL_TRUE) {
            return error.CannotInitGLFW;
        }
        defer c.glfwTerminate();

        try self.initWindow();
        defer c.glfwDestroyWindow(self.window);

        try self.pixels.init(self.k.allocator);
        defer self.pixels.deinit();

        try self.characters.init(self.k.allocator);
        defer self.characters.deinit();

        self.resources.screen.resource.image = &self.pixels.image;
        self.resources.screen.handle = try self.resource_manager.register(
            &self.resources.screen.resource,
        );

        self.resources.characters.resource.image = &self.characters.spritesheet;
        self.resources.characters.handle = try self.resource_manager.register(
            &self.resources.characters.resource,
        );

        gamepad.init();

        std.debug.print("pyon vPC\n", .{});

        self.startup_semaphore.post();

        while (true) {
            const should_close = c.glfwWindowShouldClose(self.window) == c.GL_TRUE;
            if (should_close) {
                self.input_channel.push(InputEventTag.close);
                break;
            }

            if (self.video_mutex.tryLock()) {
                self.pixels.update();
                self.characters.update();
                self.video_mutex.unlock();
            }

            c.glClear(c.GL_COLOR_BUFFER_BIT);
            self.pixels.draw();
            self.characters.draw();

            c.glfwSwapBuffers(self.window);

            c.glfwPollEvents();
            gamepad.poll(&self.input_channel);

            std.Thread.sleep(15_000_000);
        }
    }

    // ===

    fn registerExternals(self: *@This(), k: *Kernel) !void {
        try k.addExternal("poll", .{
            .callback = exts.poll,
            .userdata = self,
        });
        try k.addExternal("deinit", .{
            .callback = exts.deinit,
            .userdata = self,
        });
        try k.addExternal("<v", .{
            .callback = exts.videoLock,
            .userdata = self,
        });
        try k.addExternal("<v?", .{
            .callback = exts.videoTryLock,
            .userdata = self,
        });
        try k.addExternal("v>", .{
            .callback = exts.videoUnlock,
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
        try k.addExternal("talloc", .{
            .callback = exts.createTimer,
            .userdata = self,
        });
        try k.addExternal("tfree", .{
            .callback = exts.freeTimer,
            .userdata = self,
        });
        try k.addExternal("t!", .{
            .callback = exts.setTimer,
            .userdata = self,
        });
        try k.addExternal("t@", .{
            .callback = exts.checkTimer,
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
        try k.addExternal("i!mask", .{
            .callback = exts.imageSetMask,
            .userdata = self,
        });
        try k.addExternal("i!fill", .{
            .callback = exts.imageFill,
            .userdata = self,
        });
        try k.addExternal("i!rand", .{
            .callback = exts.imageRandomize,
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
