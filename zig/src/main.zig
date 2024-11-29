const std = @import("std");
const Allocator = std.mem.Allocator;

const mem = @import("memory.zig");

const runtime = @import("runtime.zig");
const Runtime = runtime.Runtime;
const Cell = runtime.Cell;
const ExternalError = runtime.ExternalError;

const CliOptions = @import("repl/cli_options.zig").CliOptions;
const Repl = @import("repl/repl.zig").Repl;

const System = @import("system/system.zig").System;

const BufferRefiller = @import("refillers/buffer_refiller.zig").BufferRefiller;
const StdInRefiller = @import("refillers/stdin_refiller.zig").StdInRefiller;

// ===

const base_file = @embedFile("base.mini.fth");

fn external(rt: *Runtime, token: Cell, userdata: ?*anyopaque) ExternalError!void {
    _ = userdata;
    std.debug.print("from main {}\n", .{token});
    std.debug.print("{}\n", .{rt.data_stack.top});
}

fn runVM(allocator: Allocator) !void {
    const memory = try mem.allocateMemory(allocator);
    defer allocator.free(memory);

    var rt: Runtime = undefined;
    rt.init(allocator, memory);

    var stdin: StdInRefiller = undefined;
    stdin.init();
    try rt.input_buffer.pushRefiller(stdin.toRefiller());

    stdin.prompt = "> ";

    var buffer: BufferRefiller = undefined;
    buffer.init(base_file);
    try rt.input_buffer.pushRefiller(buffer.toRefiller());

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

    // TODO load and interpret each file in cli_options

    if (cli_options.run_system) {
        // TODO run this in a separate thread
        //         if (cli_options.interactive) {
        //             try Repl.start(allocator);
        //         }

        var system: System = undefined;
        try system.init();
        try system.start();
        defer system.stop();
        defer system.deinit();
    } else {
        if (cli_options.interactive) {
            try Repl.start(allocator);
        }
    }

    // TODO
    // note: the system or the repl will have thier own loops,
    //   and this wont be called here
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
