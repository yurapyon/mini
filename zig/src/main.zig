const std = @import("std");
const Allocator = std.mem.Allocator;

const mem = @import("memory.zig");

const CliOptions = @import("cli_options.zig").CliOptions;

const readFile = @import("utils/read-file.zig").readFile;

const Kernel = @import("kernel.zig").Kernel;

// ===

const base_file = @embedFile("base.mini.fth");

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    var cli_options: CliOptions = undefined;
    try cli_options.initFromProcessArgs(allocator);
    defer cli_options.deinit();

    const memory = try mem.allocateMemory(allocator);
    defer allocator.free(memory);

    // var start_token = repl.max_external_id;

    if (cli_options.kernel_filepath) |precompiled_filepath| {
        if (cli_options.image_filepath) |image_filepath| {
            var kernel: Kernel = undefined;
            try kernel.init(allocator, image_filepath);
            const precompiled = try readFile(allocator, precompiled_filepath);
            kernel.load(precompiled);
            try kernel.execute();
            return;
        }
    }
}

test "lib-testing" {}

test "end-to-end" {}
