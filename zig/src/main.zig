const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const vm = @import("mini.zig");
const memory = @import("memory.zig");

const base_file = @embedFile("base.mini.fth");

comptime {
    const native_endianness = builtin.target.cpu.arch.endian();
    if (native_endianness != .little) {
        // TODO convert u16s to little endian on memory write
        @compileError("native endianness must be .little");
    }
}

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
    var mem: memory.CellAlignedMemory = undefined;
    try mem.init(allocator);
    defer mem.deinit();

    var vm_instance: vm.MiniVM = undefined;
    try vm_instance.init(mem);

    try vm_instance.dictionary.compileConstant("asdf", 100);

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
