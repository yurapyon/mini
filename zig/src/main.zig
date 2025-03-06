const std = @import("std");
const Allocator = std.mem.Allocator;

const mem = @import("memory.zig");

const CliOptions = @import("cli_options.zig").CliOptions;

const readFile = @import("utils/read-file.zig").readFile;

const Kernel = @import("kernel.zig").Kernel;

// ===

// const base_file = @embedFile("base.mini.fth");
const self_host_file = @embedFile("self-host.mini.fth");

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    var cli_options: CliOptions = undefined;
    try cli_options.initFromProcessArgs(allocator);
    defer cli_options.deinit();

    const memory = try mem.allocateMemory(allocator);
    defer allocator.free(memory);

    if (cli_options.kernel_filepath) |precompiled_filepath| {
        if (cli_options.image_filepath) |image_filepath| {
            var k: Kernel = undefined;
            try k.init(allocator, image_filepath);

            try @import("lib/os.zig").registerExternals(&k);

            const precompiled = try readFile(allocator, precompiled_filepath);
            k.load(precompiled);

            if (cli_options.precompile) {
                k.setAcceptBuffer(self_host_file);
            }

            try k.execute();
            return;
        }
    }
}

test "lib-testing" {}

test "end-to-end" {}
