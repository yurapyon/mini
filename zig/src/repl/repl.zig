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

fn external_fn(rt: *Runtime, token: Cell, userdata: ?*anyopaque) External.Error!bool {
    _ = userdata;
    std.debug.print("from main {}\n", .{token});
    std.debug.print("{}\n", .{rt.data_stack.top});
    return true;
}

pub const Repl = struct {
    prompt_callback: ?Cell,

    pub fn start(rt: *Runtime) !void {
        var stdin: StdInRefiller = undefined;
        stdin.init();
        try rt.input_buffer.pushRefiller(stdin.toRefiller());

        stdin.prompt = "> ";

        const external = External{
            .callback = external_fn,
            .userdata = null,
        };
        const wlidx = runtime.CompileState.interpret.toWordlistIndex() catch unreachable;
        try rt.defineExternal("emit", wlidx, 64);
        try rt.addExternal(external);

        try printBanner();

        try rt.repl();
    }

    fn printBanner() !void {
        const stdout_file = std.io.getStdOut().writer();
        var bw = std.io.bufferedWriter(stdout_file);
        try bw.writer().print("mini\n", .{});
        try bw.flush();
    }
};
