const std = @import("std");
const Allocator = std.mem.Allocator;

const mem = @import("memory.zig");

const runtime = @import("runtime.zig");
const Runtime = runtime.Runtime;
const Cell = runtime.Cell;
const ExternalError = runtime.ExternalError;

const CliOptions = @import("cli_options.zig").CliOptions;

const Repl = @import("repl.zig").Repl;

// ===

const base_file = @embedFile("base.mini.fth");

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

fn external(rt: *Runtime, token: Cell, userdata: ?*anyopaque) ExternalError!void {
    _ = userdata;
    std.debug.print("from main {}\n", .{token});
    std.debug.print("{}\n", .{rt.data_stack.top});
}

fn runVM(allocator: Allocator) !void {
    const memory = try mem.allocateMemory(allocator);
    defer allocator.free(memory);

    var rt: Runtime = undefined;
    rt.init(memory);

    var refiller: LineByLineRefiller = undefined;
    refiller.init(base_file);

    rt.input_buffer.refill_callback = LineByLineRefiller.refill;
    rt.input_buffer.refill_userdata = &refiller;

    rt.externals_callback = external;
    const wlidx = runtime.CompileState.interpret.toWordlistIndex() catch unreachable;
    try rt.defineExternal("hi", wlidx, 500);

    try rt.repl();
}

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    var cli_options: CliOptions = undefined;
    try cli_options.initFromProcessArgs(allocator);
    defer cli_options.deinit();

    if (cli_options.interactive) {
        try Repl.start(allocator);
    } else if (cli_options.run_system) {
        // TODO start graphics sytem
    }

    // TODO load and interpret each file in cli_options

    try runVM(std.heap.c_allocator);
}

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
