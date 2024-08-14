const std = @import("std");
const Allocator = std.mem.Allocator;

const mem = @import("memory.zig");

const runtime = @import("runtime.zig");
const Runtime = runtime.Runtime;

// pub fn readFile(allocator: Allocator, filename: []const u8) ![]u8 {
//     var file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
//     defer file.close();
//     return file.readToEndAlloc(allocator, std.math.maxInt(usize));
// }

const base_file = @embedFile("common/base.mini.fth");

const LineByLineRefiller = struct {
    buffer: [128]u8,
    stream: std.io.FixedBufferStream([]const u8),

    fn init(self: *@This(), buffer: []const u8) void {
        self.stream = std.io.fixedBufferStream(buffer);
    }

    fn refill(self_: ?*anyopaque) error{CannotRefill}!?[]const u8 {
        const self: *@This() = @ptrCast(@alignCast(self_));
        const slice = self.stream.reader().readUntilDelimiterOrEof(
            self.buffer[0..self.buffer.len],
            '\n',
        ) catch return error.CannotRefill;
        if (slice) |slc| {
            return self.buffer[0..slc.len];
        } else {
            return null;
        }
    }
};

fn runVM(allocator: Allocator) !void {
    const memory = try mem.allocateMemory(allocator);
    defer allocator.free(memory);

    var rt: Runtime = undefined;
    rt.init(memory);

    var refiller: LineByLineRefiller = undefined;
    refiller.init(base_file);

    rt.input_buffer.refill_callback = LineByLineRefiller.refill;
    rt.input_buffer.refill_userdata = &refiller;

    try rt.repl();
}

pub fn main() !void {}

test "lib-testing" {
    _ = @import("bytecodes.zig");
    _ = @import("dictionary.zig");
    _ = @import("input_buffer.zig");
    _ = @import("linked_list_iterator.zig");
    _ = @import("memory.zig");
    _ = @import("register.zig");
    _ = @import("runtime.zig");
    _ = @import("stack.zig");
    _ = @import("utils.zig");
}

test "end-to-end" {
    try runVM(std.testing.allocator);
}
