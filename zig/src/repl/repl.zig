const std = @import("std");
const Allocator = std.mem.Allocator;

const mem = @import("../memory.zig");

const runtime = @import("../runtime.zig");
const Runtime = runtime.Runtime;
const Cell = runtime.Cell;
const ExternalError = runtime.ExternalError;

const externals = @import("../externals.zig");
const External = externals.External;

const CliOptions = @import("cli_options.zig").CliOptions;

const BufferRefiller = @import("../refillers/buffer_refiller.zig").BufferRefiller;
const StdInRefiller = @import("../refillers/stdin_refiller.zig").StdInRefiller;

// ===

const repl_file = @embedFile("repl.mini.fth");

fn external_fn(rt: *Runtime, token: Cell, userdata: ?*anyopaque) External.Error!bool {
    const repl = @as(*Repl, @ptrCast(@alignCast(userdata)));
    switch (token) {
        64 => {
            const raw_char = rt.data_stack.pop();
            const char = @as(u8, @truncate(raw_char & 0xff));
            repl.emit(char) catch return error.ExternalPanic;
        },
        65 => {
            const cell = rt.data_stack.pop();
            repl.dot(cell) catch return error.ExternalPanic;
        },
        else => return false,
    }
    return true;
}

pub const Repl = struct {
    // TODO use this?
    prompt_xt: ?Cell,
    output_file: std.fs.File,

    pub fn init(self: *@This()) void {
        self.output_file = std.io.getStdOut();
    }

    pub fn start(self: *@This(), rt: *Runtime) !void {
        var stdin: StdInRefiller = undefined;
        stdin.init();
        try rt.input_buffer.pushRefiller(stdin.toRefiller());

        stdin.prompt = "> ";

        const external = External{
            .callback = external_fn,
            .userdata = self,
        };
        const wlidx = runtime.CompileState.interpret.toWordlistIndex() catch unreachable;
        try rt.defineExternal("emit", wlidx, 64);
        try rt.defineExternal(".", wlidx, 65);
        try rt.addExternal(external);

        try rt.processBuffer(repl_file);

        try self.printBanner();

        try rt.interpretLoop();
    }

    fn printBanner(self: *@This()) !void {
        var bw = std.io.bufferedWriter(self.output_file.writer());
        try bw.writer().print("mini\n", .{});
        try bw.flush();
    }

    fn emit(self: *@This(), char: u8) !void {
        var bw = std.io.bufferedWriter(self.output_file.writer());
        try bw.writer().print("{c}", .{char});
        try bw.flush();
    }

    fn dot(self: *@This(), value: Cell) !void {
        var bw = std.io.bufferedWriter(self.output_file.writer());
        try bw.writer().print("{d} ", .{value});
        try bw.flush();
    }
};
