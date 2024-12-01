const std = @import("std");
const Allocator = std.mem.Allocator;

const mem = @import("memory.zig");

const runtime = @import("runtime.zig");
const Runtime = runtime.Runtime;
const Cell = runtime.Cell;

const externals = @import("externals.zig");
const External = externals.External;

const CliOptions = @import("repl/cli_options.zig").CliOptions;
const Repl = @import("repl/repl.zig").Repl;

const System = @import("system/system.zig").System;

const BufferRefiller = @import("refillers/buffer_refiller.zig").BufferRefiller;
const StdInRefiller = @import("refillers/stdin_refiller.zig").StdInRefiller;

// ===

const base_file = @embedFile("base.mini.fth");

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    var cli_options: CliOptions = undefined;
    try cli_options.initFromProcessArgs(allocator);
    defer cli_options.deinit();

    const memory = try mem.allocateMemory(allocator);
    defer allocator.free(memory);

    var rt: Runtime = undefined;
    rt.init(allocator, memory);

    // TODO make sure this runs before going to the repl
    var buffer: BufferRefiller = undefined;
    buffer.init(base_file);
    try rt.input_buffer.pushRefiller(buffer.toRefiller());

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
            try Repl.start(&rt);
        }
    }
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
    // TODO
    // try runVM(std.testing.allocator);
}
