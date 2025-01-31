const std = @import("std");
const Allocator = std.mem.Allocator;

const mem = @import("memory.zig");

const runtime = @import("runtime.zig");
const Runtime = runtime.Runtime;
const Cell = runtime.Cell;

const externals = @import("externals.zig");
const External = externals.External;

const CliOptions = @import("cli_options.zig").CliOptions;

const repl = @import("repl/repl.zig");
const Repl = repl.Repl;

const Dynamic = @import("lib/dynamic.zig").Dynamic;
const Blocks = @import("lib/blocks.zig").Blocks;

const System = @import("system/system.zig").System;

const readFile = @import("utils/read-file.zig").readFile;

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

    rt.processBuffer(base_file) catch |err| switch (err) {
        error.WordNotFound => {
            std.debug.print("Word not found: {s}\n", .{
                rt.last_evaluated_word orelse unreachable,
            });
            return err;
        },
        else => return err,
    };

    var start_token = repl.max_external_id;

    var lib_dynamic: Dynamic = undefined;
    lib_dynamic.init(&rt);
    start_token = try lib_dynamic.initLibrary(start_token);

    var lib_blocks: Blocks = undefined;
    if (cli_options.image_filepath) |image_filepath| {
        lib_blocks.init(&rt, image_filepath);
        start_token = lib_blocks.initLibrary(start_token) catch |err| switch (err) {
            error.WordNotFound => {
                std.debug.print("Word not found: {s}\n", .{
                    rt.last_evaluated_word orelse unreachable,
                });
                return err;
            },
            else => return err,
        };
    }

    var lib_repl: Repl = undefined;
    try lib_repl.init(&rt);

    for (cli_options.filepaths.items) |filepath| {
        const file_buffer = try readFile(allocator, filepath);
        defer allocator.free(file_buffer);

        // TODO if you comment out line 85 and there is a wnf error thrown but the code
        // it puts the repl in a weird state
        rt.processBuffer(file_buffer) catch |err| switch (err) {
            error.WordNotFound => {
                std.debug.print("Word not found: {s}\n", .{
                    rt.last_evaluated_word orelse unreachable,
                });
                return err;
            },
            else => return err,
        };
    }

    if (cli_options.run_system) {
        // TODO NOTE
        // could run this in a separate thread
        // if (cli_options.interactive) {
        //   try Repl.start(allocator);
        // }

        var system: System = undefined;
        try system.init(&rt);
        try system.loop();
        defer system.deinit();
    } else {
        if (cli_options.interactive) {
            try lib_repl.start(&rt);
        }
    }
}

test "lib-testing" {
    _ = @import("bytecodes.zig");
    _ = @import("dictionary.zig");
    _ = @import("input_buffer.zig");
    _ = @import("utils/linked_list_iterator.zig");
    _ = @import("memory.zig");
    _ = @import("register.zig");
    _ = @import("runtime.zig");
    _ = @import("stack.zig");
    // _ = @import("utils.zig");
}

test "end-to-end" {
    // TODO
    // try runVM(std.testing.allocator);
}
