const std = @import("std");
const Allocator = std.Allocator;
const Thread = std.Thread;

const vm = @import("mini.zig");

pub const System = struct {
    allocator: Allocator,

    vm_memory: vm.mem.CellAlignedMemory,
    vm_thread: ?Thread,

    should_exit: bool,

    pub fn init(self: *@This(), allocator: Allocator) !void {
        self.allocator = allocator;

        self.vm_memory = try vm.mem.allocateCellAlignedMemory(
            self.allocator,
            vm.max_memory_size,
        );
        errdefer self.allocator.free(self.vm_memory);

        self.vm_thread = null;

        self.should_exit = false;
    }

    pub fn deinit(self: @This()) void {
        self.allocator.free(self.vm_memory);
    }

    // ===

    pub fn start(self: *@This()) !void {
        self.vm_thread = try Thread.spawn(.{}, runVM, self.vm_memory);
    }

    pub fn stop(self: *@This()) void {
        if (self.vm_thread) |thr| {
            // TODO set something telling the vm to exit its main loop
            thr.join();
        }
    }

    pub fn mainLoop(self: *@This()) !void {
        while (!self.should_exit) {
            // 1/60
            std.time.nanosleep(16000000);
        }
    }
};

fn runVM(memory: vm.mem.CellAlignedMemory) !void {
    var vm_instance: vm.MiniVM = undefined;
    try vm_instance.init(memory);

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

const base_file = @embedFile("common/base.mini.fth");

const LineByLineRefiller = struct {
    // NOTE
    // 127 because of the terminator that will be added in the input buffer
    buffer: [127]u8,
    stream: std.io.FixedBufferStream([]const u8),

    fn init(self: *@This(), buffer: []const u8) void {
        self.stream = std.io.fixedBufferStream(buffer);
    }

    fn refill(self_: *anyopaque) vm.InputError!?[]const u8 {
        const self: *LineByLineRefiller = @ptrCast(@alignCast(self_));
        const slice = self.stream.reader().readUntilDelimiterOrEof(
            self.buffer[0 .. self.buffer.len - 1],
            '\n',
        ) catch return error.OversizeInputBuffer;
        if (slice) |slc| {
            self.buffer[slc.len] = '\n';
            return self.buffer[0..(slc.len + 1)];
        } else {
            return null;
        }
    }
};
