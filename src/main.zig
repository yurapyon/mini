const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Thread = std.Thread;

const mini = @import("mini");

const mem = mini.mem;

const kernel = mini.kernel;
const Kernel = kernel.Kernel;
const Cell = kernel.Cell;
const FFI = kernel.FFI;
const Accept = kernel.Accept;

const Handles = mini.utils.Handles;

const System = @import("pyon").system.System;

const libs = @import("libs");
const externals = libs.externals;
const External = externals.External;
const ExternalsList = externals.ExternalsList;

const OS = libs.os.OS;
const Dynamic = libs.dynamic.Dynamic;
const Randomizer = libs.random.Randomizer;

const CliOptions = @import("cli_options.zig").CliOptions;

// ===

fn emitStdOut(char: u8, userdata: ?*anyopaque) void {
    var buf = [_]u8{0} ** 256;

    const output_file = @as(*std.fs.File, @ptrCast(@alignCast(userdata)));
    // var bw = std.io.Writer.buffered(output_file.writer());
    var fw = std.fs.File.Writer.init(output_file.*, &buf);
    fw.interface.writeByte(char) catch unreachable;
    fw.interface.flush() catch unreachable;
}

fn acceptStdIn(
    k: *Kernel,
    userdata: ?*anyopaque,
    buf_addr: Cell,
    buf_len: Cell,
) Accept.Error!Cell {
    const out = try mem.sliceFromAddrAndLen(
        k.memory,
        buf_addr,
        buf_len,
    );

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

fn ffiCallback(k: *Kernel, userdata: ?*anyopaque, ext_token: Cell) FFI.Error!void {
    const exts: *ExternalsList = @ptrCast(@alignCast(userdata));
    if (ext_token < exts.externals.items.len) {
        const ext = exts.externals.items[ext_token];
        ext.call(k) catch |err| switch (err) {
            error.ExternalPanic => return error.Panic,
            else => |e| return e,
        };
    } else {
        return error.UnhandledExternal;
    }
}

fn ffiLookup(_: *Kernel, userdata: ?*anyopaque, name: []const u8) ?Cell {
    const exts: *ExternalsList = @ptrCast(@alignCast(userdata));
    return exts.lookup(name);
}

fn kernelRunFiles(
    system: *System,
    k: *Kernel,
    allocator: Allocator,
    filepaths: ArrayList([]u8),
    start_repl: bool,
) !void {
    system.startup_semaphore.wait();

    var input_file = std.fs.File.stdin();

    for (filepaths.items) |fp| {
        const file = try mini.utils.readFile(allocator, fp);
        defer allocator.free(file);

        std.debug.print(">> {s}\n", .{fp});
        try k.evaluate(file);
    }

    // TODO
    // note this leds to some weird behavior
    // can be fixed by redefining 'bye'
    if (start_repl) {
        std.debug.print("(mini)\n", .{});

        k.setAcceptClosure(.{
            .callback = acceptStdIn,
            .userdata = &input_file,
            .is_async = false,
        });
        k.initForth();
        try k.execute();
    }
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
        const forth_memory = try mini.mem.allocateForthMemory(allocator);

        var exts: ExternalsList = undefined;
        exts.init(allocator);

        var k: Kernel = undefined;
        k.init(forth_memory);

        var h: Handles = undefined;
        h.init();
        defer h.deinit(allocator);

        const image = try mini.utils.readFile(allocator, precompiled_filepath);
        defer allocator.free(image);
        k.loadImage(image);

        const should_start_repl =
            cli_options.interactive or
            cli_options.filepaths.items.len == 0;

        if (cli_options.precompile) {
            k.setAcceptClosure(.{
                .callback = acceptStdIn,
                .userdata = &input_file,
                .is_async = false,
            });

            k.setEmitClosure(.{
                .callback = emitStdOut,
                .userdata = &output_file,
            });

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
            mini.utils.writeFile(filename, bytes) catch unreachable;
        } else if (cli_options.run_system) {
            try libs.floats.pushExternals(&exts);

            var os: OS = undefined;
            os.init(allocator);
            try os.pushExternals(&exts);

            var dyn: Dynamic = undefined;
            dyn.init(allocator, &h);
            try dyn.pushExternals(&exts);

            var r: Randomizer = undefined;
            r.init();
            try r.pushExternals(&exts);

            var sys: System = undefined;
            try sys.pushExternals(&exts);

            k.setFFIClosure(.{
                .callback = ffiCallback,
                .lookup = ffiLookup,
                .userdata = &exts,
            });

            k.clearAcceptClosure();
            k.setEmitClosure(.{
                .callback = emitStdOut,
                .userdata = &output_file,
            });

            k.debug_accept_buffer = false;

            std.debug.print(">> startup\n", .{});
            try k.evaluate(startup_file);
            try k.evaluate(libs.floats.getStartupFile());
            try k.evaluate(os.getStartupFile());
            try k.evaluate(dyn.getStartupFile());
            try k.evaluate(r.getStartupFile());

            try sys.init(&k, &h, allocator);
            defer sys.deinit();

            const kernel_thread = try Thread.spawn(
                .{},
                kernelRunFiles,
                .{
                    &sys,
                    &k,
                    allocator,
                    cli_options.filepaths,
                    should_start_repl,
                },
            );

            try sys.run();

            kernel_thread.join();
        } else {
            try libs.floats.pushExternals(&exts);

            var os: OS = undefined;
            os.init(allocator);
            try os.pushExternals(&exts);

            var dyn: Dynamic = undefined;
            dyn.init(allocator, &h);
            try dyn.pushExternals(&exts);

            var r: Randomizer = undefined;
            r.init();
            try r.pushExternals(&exts);

            k.setFFIClosure(.{
                .callback = ffiCallback,
                .lookup = ffiLookup,
                .userdata = &exts,
            });

            k.clearAcceptClosure();
            k.setEmitClosure(.{
                .callback = emitStdOut,
                .userdata = &output_file,
            });

            k.debug_accept_buffer = false;

            std.debug.print(">> startup\n", .{});
            try k.evaluate(startup_file);
            try k.evaluate(libs.floats.getStartupFile());
            try k.evaluate(os.getStartupFile());
            try k.evaluate(dyn.getStartupFile());
            try k.evaluate(r.getStartupFile());

            for (cli_options.filepaths.items) |fp| {
                const file = try mini.utils.readFile(allocator, fp);
                defer allocator.free(file);

                std.debug.print(">> {s}\n", .{fp});
                try k.evaluate(file);
            }

            if (should_start_repl) {
                std.debug.print("(mini)\n", .{});

                k.setAcceptClosure(.{
                    .callback = acceptStdIn,
                    .userdata = &input_file,
                    .is_async = false,
                });
                // TODO note
                // This restarts the interpreter
                // Not sure if this is best to do
                k.initForth();
                try k.execute();
            }
        }

        return;
    }
}

test "lib-testing" {}

test "end-to-end" {
    // TODO
    // _ = @import("utils/os-timer.zig");
    // _ = @import("utils/channel.zig");
}
