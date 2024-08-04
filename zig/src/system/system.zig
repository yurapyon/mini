const std = @import("std");
const Allocator = std.mem.Allocator;
const Thread = std.Thread;

const vm = @import("../mini.zig");
const c = @import("c.zig");

pub const System = struct {
    allocator: Allocator,

    vm_memory: vm.mem.CellAlignedMemory,
    vm_thread: ?Thread,

    should_exit: std.atomic.Value(bool),

    pub fn init(self: *@This(), allocator: Allocator) !void {
        self.allocator = allocator;

        self.vm_memory = try vm.mem.allocateCellAlignedMemory(
            self.allocator,
            vm.max_memory_size,
        );
        errdefer self.allocator.free(self.vm_memory);

        self.vm_thread = null;

        self.should_exit = @TypeOf(self.should_exit).init(false);

        try c.initGraphics();
    }

    pub fn deinit(self: @This()) void {
        c.deinitGraphics();
        self.allocator.free(self.vm_memory);
    }

    // ===

    pub fn start(self: *@This()) !void {
        self.vm_thread = try Thread.spawn(.{}, runVM, .{ self, self.vm_memory });
    }

    pub fn stop(self: *@This()) void {
        if (self.vm_thread) |thr| {
            // TODO set something telling the vm to exit its main loop
            thr.join();
        }
    }

    pub fn mainLoop(self: *@This()) !void {
        while (!self.should_exit.load(.unordered)) {

            // c.glClear(c.GL_COLOR_BUFFER_BIT);
            // c.glfwSwapBuffers(window);
            // c.glfwPollEvents();

            // 1/60
            std.time.sleep(16000000);
        }
    }

    fn runVM(self: *@This(), memory: vm.mem.CellAlignedMemory) !void {
        var vm_instance: vm.MiniVM = undefined;
        try vm_instance.init(memory, .{
            .userdata = self,
            .onBye = callbacks.onBye,
        });

        var refiller: LineByLineRefiller = undefined;
        refiller.init(base_file);

        vm_instance.should_bye = false;
        vm_instance.should_quit = false;
        vm_instance.input_source.setRefillCallback(
            LineByLineRefiller.refill,
            @ptrCast(&refiller),
        );
        try vm_instance.repl();
    }
};

const callbacks = struct {
    fn onBye(_: *vm.MiniVM, maybe_self: ?*anyopaque) vm.Error!bool {
        if (maybe_self) |self_| {
            const self = @as(*System, @ptrCast(@alignCast(self_)));

            std.debug.print("byebye\n", .{});
            self.should_exit.store(true, .unordered);
        }
        return true;
    }
};

const base_file = @embedFile("../common/base.mini.fth");

const LineByLineRefiller = struct {
    buffer: [128]u8,
    stream: std.io.FixedBufferStream([]const u8),

    fn init(self: *@This(), buffer: []const u8) void {
        self.stream = std.io.fixedBufferStream(buffer);
    }

    fn refill(self_: *anyopaque) vm.InputError!?[]const u8 {
        const self: *LineByLineRefiller = @ptrCast(@alignCast(self_));
        const slice = self.stream.reader().readUntilDelimiterOrEof(
            self.buffer[0..self.buffer.len],
            '\n',
        ) catch return error.OversizeInputBuffer;
        if (slice) |slc| {
            return self.buffer[0..slc.len];
        } else {
            return null;
        }
    }
};
