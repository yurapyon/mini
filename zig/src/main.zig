const std = @import("std");
const Allocator = std.mem.Allocator;

const vm = @import("mini.zig");

const base_file = @embedFile("base.mini.fth");

pub fn readFile(allocator: Allocator, filename: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
    defer file.close();
    return file.readToEndAlloc(allocator, std.math.maxInt(usize));
}

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

fn runMiniVM(allocator: Allocator) !void {
    const mem = try vm.mem.allocateCellAlignedMemory(
        allocator,
        vm.max_memory_size,
    );
    defer allocator.free(mem);

    var vm_instance: vm.MiniVM = undefined;
    try vm_instance.init(mem);

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

pub fn main() !void {
    try runMiniVM(std.heap.c_allocator);
}

test "lib-testing" {
    _ = @import("stack.zig");
    _ = @import("word_header.zig");
    _ = @import("utils.zig");
    _ = @import("register.zig");
    _ = @import("input_source.zig");
    _ = @import("dictionary.zig");
    _ = @import("memory.zig");
    _ = @import("mini.zig");
}

test "end-to-end" {
    try runMiniVM(std.testing.allocator);
}
