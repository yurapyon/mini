const std = @import("std");
const Allocator = std.mem.Allocator;

const mem = @import("memory.zig");

const CliOptions = @import("cli_options.zig").CliOptions;

const readFile = @import("utils/read-file.zig").readFile;
const writeFile = @import("utils/read-file.zig").writeFile;

const kernel = @import("kernel.zig");
const Kernel = kernel.Kernel;
const Cell = kernel.Cell;

// ===

fn emitStdOut(char: u8, userdata: ?*anyopaque) void {
    const output_file = @as(*std.fs.File, @ptrCast(@alignCast(userdata)));
    var bw = std.io.bufferedWriter(output_file.writer());
    bw.writer().writeByte(char) catch unreachable;
    bw.flush() catch unreachable;
}

fn acceptStdIn(out: []u8, userdata: ?*anyopaque) error{CannotAccept}!Cell {
    const input_file = @as(*std.fs.File, @ptrCast(@alignCast(userdata)));
    const reader = input_file.reader();
    const slice =
        reader.readUntilDelimiterOrEof(
            out[0..out.len],
            '\n',
        ) catch return error.CannotAccept;
    if (slice) |slc| {
        return @truncate(slc.len);
    } else {
        return 0;
    }
}

// const base_file = @embedFile("base.mini.fth");
const self_host_file = @embedFile("self-host.mini.fth");

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    var cli_options: CliOptions = undefined;
    try cli_options.initFromProcessArgs(allocator);
    defer cli_options.deinit();

    const memory = try mem.allocateMemory(allocator);
    defer allocator.free(memory);

    var input_file = std.io.getStdIn();
    var output_file = std.io.getStdOut();

    if (cli_options.kernel_filepath) |precompiled_filepath| {
        var k: Kernel = undefined;
        try k.init(allocator);

        k.setAcceptClosure(acceptStdIn, &input_file);
        k.setEmitClosure(emitStdOut, &output_file);

        try @import("lib/os.zig").registerExternals(&k);

        const precompiled = try readFile(allocator, precompiled_filepath);
        k.load(precompiled);

        if (cli_options.precompile) {
            try k.setAcceptBuffer(self_host_file);
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
        } else {
            // TODO
            // Load std lib

            try k.execute();
        }

        return;
    }
}

test "lib-testing" {}

test "end-to-end" {}
