const std = @import("std");
const Allocator = std.mem.Allocator;

const mem = @import("memory.zig");

const CliOptions = @import("cli_options.zig").CliOptions;

const readFile = @import("utils/read-file.zig").readFile;
const writeFile = @import("utils/read-file.zig").writeFile;

const kernel = @import("kernel.zig");
const Kernel = kernel.Kernel;
const Cell = kernel.Cell;

const System = @import("system/system.zig").System;

// ===

fn emitStdOut(char: u8, userdata: ?*anyopaque) void {
    var buf = [_]u8{0} ** 256;

    const output_file = @as(*std.fs.File, @ptrCast(@alignCast(userdata)));
    // var bw = std.io.Writer.buffered(output_file.writer());
    var fw = std.fs.File.Writer.init(output_file.*, &buf);
    fw.interface.writeByte(char) catch unreachable;
    fw.interface.flush() catch unreachable;
}

fn acceptStdIn(out: []u8, userdata: ?*anyopaque) error{CannotAccept}!Cell {
    // TODO handle EoF

    var buf = [_]u8{0} ** 256;

    var bw = std.Io.Writer.fixed(out);

    const input_file = @as(*std.fs.File, @ptrCast(@alignCast(userdata)));
    var fr = input_file.reader(&buf);
    const len = fr.interface.streamDelimiterEnding(
        &bw,
        '\n',
    ) catch return error.CannotAccept;

    return @truncate(len);
}

const startup_file = @embedFile("startup.mini.fth");
const self_host_file = @embedFile("self-host.mini.fth");

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    var cli_options: CliOptions = undefined;
    try cli_options.initFromProcessArgs(allocator);
    defer cli_options.deinit(allocator);

    var input_file = std.fs.File.stdin();
    var output_file = std.fs.File.stdout();

    if (cli_options.kernel_filepath) |precompiled_filepath| {
        var k: Kernel = undefined;
        try k.init(allocator);
        defer k.deinit();

        const image = try readFile(allocator, precompiled_filepath);
        defer allocator.free(image);
        k.loadImage(image);

        if (cli_options.precompile) {
            k.setAcceptClosure(acceptStdIn, &input_file);
            k.setEmitClosure(emitStdOut, &output_file);

            try k.setAcceptBuffer(self_host_file);
            k.initForth();
            try k.execute();
            const len = k.data_stack.popCell();
            const addr = k.data_stack.popCell();
            const filename = "mini-out/precompiled.mini.bin";

            const bytes = try mem.sliceFromAddrAndLen(
                k.memory,
                addr,
                len,
            );

            std.debug.print("saving: {s} \n", .{
                filename,
            });
            writeFile(filename, bytes) catch unreachable;
        } else if (cli_options.run_system) {
            try @import("lib/os.zig").registerExternals(&k);

            var sys: System = undefined;

            k.clearAcceptClosure();
            k.setEmitClosure(emitStdOut, &output_file);

            k.debug_accept_buffer = false;

            std.debug.print(">> startup\n", .{});
            try k.setAcceptBuffer(startup_file);
            k.initForth();
            try k.execute();

            try sys.init(&k);
            defer sys.deinit();
        } else {
            try @import("lib/os.zig").registerExternals(&k);

            k.clearAcceptClosure();
            k.setEmitClosure(emitStdOut, &output_file);

            k.debug_accept_buffer = false;

            std.debug.print(">> startup\n", .{});
            try k.setAcceptBuffer(startup_file);
            k.initForth();
            try k.execute();

            for (cli_options.filepaths.items) |fp| {
                const file = try readFile(allocator, fp);
                defer allocator.free(file);
                std.debug.print(">> {s}\n", .{fp});

                try k.setAcceptBuffer(file);
                k.initForth();
                try k.execute();
            }

            const should_start_repl =
                cli_options.interactive or
                cli_options.filepaths.items.len == 0;

            if (should_start_repl) {
                std.debug.print("(mini)\n", .{});

                k.setAcceptClosure(acceptStdIn, &input_file);
                k.initForth();
                try k.execute();
            }
        }

        return;
    }
}

test "lib-testing" {}

test "end-to-end" {}
