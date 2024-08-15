const std = @import("std");
const Allocator = std.mem.Allocator;

const mem = @import("memory.zig");

const runtime = @import("runtime.zig");
const Runtime = runtime.Runtime;
const Cell = runtime.Cell;
const ExternalError = runtime.ExternalError;

pub const Repl = struct {
    prompt_callback: ?Cell,

    pub fn start(allocator: Allocator) !void {
        const memory = try mem.allocateMemory(allocator);
        defer allocator.free(memory);

        var rt: Runtime = undefined;
        rt.init(memory);

        try printBanner();
    }

    fn printBanner() !void {
        const stdout_file = std.io.getStdOut().writer();
        var bw = std.io.bufferedWriter(stdout_file);
        try bw.writer().print("mini\n", .{});
        try bw.flush();
    }
};
