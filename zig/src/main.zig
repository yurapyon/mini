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
    buffer: @import("input_source.zig").InputSource.MemType,
    stream: std.io.FixedBufferStream([]const u8),

    fn init(self: *@This(), buffer: []const u8) void {
        self.stream = std.io.fixedBufferStream(buffer);
        // self.buffer = buffer;
        // self.buffer_at = 0;
    }

    fn refill(self_: *anyopaque) vm.InputError![]const u8 {
        const self: *LineByLineRefiller = @ptrCast(@alignCast(self_));
        const slice = self.stream.reader().readUntilDelimiterOrEof(
            &self.buffer,
            '\n',
        ) catch return error.OversizeInputBuffer;
        if (slice) |slc| {
            return slc;
        } else {
            return error.CannotRefill;
        }
    }
};

fn runMiniVM(allocator: Allocator) !void {
    const mem = try vm.allocateMemory(allocator);
    defer allocator.free(mem);

    var vm_instance: vm.MiniVM = undefined;
    try vm_instance.init(mem);

    try vm_instance.dictionary.compileConstant("asdf", 100);

    // try vm_instance.input_source.setInputBuffer("1 dup 1+ dup 1+ ##.s bye\n");
    // try vm_instance.repl();

    var refiller: LineByLineRefiller = undefined;
    refiller.init(base_file);

    vm_instance.should_bye = false;
    vm_instance.should_quit = false;
    // try vm_instance.input_source.setInputBuffer(base_file);
    vm_instance.input_source.setRefillCallback(
        LineByLineRefiller.refill,
        @ptrCast(&refiller),
    );
    try vm_instance.repl();
}

pub fn main() !void {}

test "lib-testing" {
    _ = @import("stack.zig");
    _ = @import("word_header.zig");
    _ = @import("utils.zig");
    _ = @import("register.zig");
    _ = @import("input_source.zig");
    _ = @import("dictionary.zig");
    _ = @import("mini.zig");
}

test "end-to-end" {
    try runMiniVM(std.testing.allocator);
}
