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

const ExternalId = enum(Cell) {
    bye = 64,
    emit,
    dot,
    showStack,
    _,
};

const repl_file = @embedFile("repl.mini.fth");

fn externalsCallback(rt: *Runtime, token: Cell, userdata: ?*anyopaque) External.Error!bool {
    const repl = @as(*Repl, @ptrCast(@alignCast(userdata)));

    const external_id = @as(ExternalId, @enumFromInt(token));

    switch (external_id) {
        .bye => {
            rt.should_quit = true;
            repl.should_bye = true;
        },
        .emit => {
            const raw_char = rt.data_stack.pop();
            const char = @as(u8, @truncate(raw_char & 0xff));
            repl.emit(char) catch return error.ExternalPanic;
        },
        .dot => {
            const cell = rt.data_stack.pop();
            repl.dot(cell) catch return error.ExternalPanic;
        },
        .showStack => {
            const count = rt.data_stack.pop();
            const u8_count: u8 = @truncate(count);
            std.debug.print("<{d}>", .{u8_count});

            var i: u8 = 0;
            while (i < u8_count) : (i += 1) {
                std.debug.print(" {d}", .{rt.data_stack.index(i)});
            }
        },
        else => return false,
    }
    return true;
}

pub const Repl = struct {
    output_file: std.fs.File,
    should_bye: bool,

    // TODO use this?
    prompt_xt: ?Cell,

    // TODO maybe save the runtime in this as a field
    pub fn init(self: *@This(), rt: *Runtime) !void {
        self.output_file = std.io.getStdOut();

        const external = External{
            .callback = externalsCallback,
            .userdata = self,
        };
        const wlidx = runtime.CompileState.interpret.toWordlistIndex() catch unreachable;
        try rt.defineExternal("bye", wlidx, @intFromEnum(ExternalId.bye));
        try rt.defineExternal("emit", wlidx, @intFromEnum(ExternalId.emit));
        try rt.defineExternal(".", wlidx, @intFromEnum(ExternalId.dot));
        try rt.defineExternal(".s", wlidx, @intFromEnum(ExternalId.showStack));
        try rt.addExternal(external);

        rt.processBuffer(repl_file) catch |err| switch (err) {
            error.WordNotFound => {
                std.debug.print("Word not found: {s}\n", .{
                    rt.last_evaluated_word orelse unreachable,
                });
                return err;
            },
            else => return err,
        };
    }

    pub fn start(self: *@This(), rt: *Runtime) !void {
        var stdin: StdInRefiller = undefined;
        stdin.init();
        rt.input_buffer.refiller = stdin.toRefiller();

        // stdin.prompt = "> ";

        try self.printBanner();

        self.should_bye = false;

        while (!self.should_bye) {
            rt.interpretUntilQuit() catch |err| switch (err) {
                error.WordNotFound => {
                    std.debug.print("Word not found: {s}\n", .{
                        rt.last_evaluated_word orelse unreachable,
                    });
                },
                else => return err,
            };
        }
    }

    fn printBanner(self: *@This()) !void {
        var bw = std.io.bufferedWriter(self.output_file.writer());
        try bw.writer().print("mini\n", .{});
        try bw.flush();
    }

    fn emit(self: *@This(), char: u8) !void {
        var bw = std.io.bufferedWriter(self.output_file.writer());
        try bw.writer().print("{c}", .{char});
        try bw.flush();
    }

    fn dot(self: *@This(), value: Cell) !void {
        var bw = std.io.bufferedWriter(self.output_file.writer());
        try bw.writer().print("{d} ", .{value});
        try bw.flush();
    }
};
