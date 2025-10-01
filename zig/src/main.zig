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
    var buf = [_]u8{0} ** 256;

    const output_file = @as(*std.fs.File, @ptrCast(@alignCast(userdata)));
    // var bw = std.io.Writer.buffered(output_file.writer());
    var fw = std.fs.File.Writer.init(output_file.*, &buf);
    fw.interface.writeByte(char) catch unreachable;
    fw.interface.flush() catch unreachable;
}

fn acceptStdIn(out: []u8, userdata: ?*anyopaque) error{CannotAccept}!Cell {
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
    defer cli_options.deinit();

    const memory = try mem.allocateMemory(allocator);
    defer allocator.free(memory);

    var input_file = std.fs.File.stdin();
    var output_file = std.fs.File.stdout();

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
        } else {
            k.debug_accept_buffer = false;
            try k.setAcceptBuffer(startup_file);
            k.initForth();
            try k.execute();
        }

        return;
    }
}

test "lib-testing" {}

test "end-to-end" {}
