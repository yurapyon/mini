const std = @import("std");
const Allocator = std.mem.Allocator;

const runtime = @import("../runtime.zig");
const Runtime = runtime.Runtime;
const Cell = runtime.Cell;
const ExternalError = runtime.ExternalError;

const externals = @import("../externals.zig");
const External = externals.External;

const ReplRefiller = @import("repl_refiller.zig").ReplRefiller;

// ===

const ExternalId = enum(Cell) {
    bye = 64,
    emit,
    showStack,
    key,
    rawMode,
    sqrt,
    _max,
    _,
};

pub const max_external_id = @intFromEnum(ExternalId._max);

const repl_file = @embedFile("repl.mini.fth");
const repl_start_file = @embedFile("repl-start.mini.fth");

fn externalsCallback(rt: *Runtime, token: Cell, userdata: ?*anyopaque) External.Error!bool {
    const repl = @as(*Repl, @ptrCast(@alignCast(userdata)));

    const external_id = @as(ExternalId, @enumFromInt(token));

    switch (external_id) {
        .bye => {
            // TODO this should call rt.quit()
            rt.should_quit = true;
            repl.should_bye = true;
        },
        .emit => {
            const raw_char = rt.data_stack.pop();
            const char = @as(u8, @truncate(raw_char & 0xff));
            repl.emit(char) catch return error.ExternalPanic;
        },
        .showStack => {
            // TODO
            // something about this is broken
            const count = rt.data_stack.pop();
            const u8_count: u8 = @truncate(count);
            std.debug.print("<{d}>", .{u8_count});

            var i: u8 = 0;
            while (i < u8_count) : (i += 1) {
                std.debug.print(" {d}", .{rt.data_stack.index(i)});
            }
        },
        .key => {},
        .sqrt => {
            const value = rt.data_stack.pop();
            const sqrt_value = std.math.sqrt(value);
            rt.data_stack.push(sqrt_value);
        },
        else => return false,
    }
    return true;
}

pub const Repl = struct {
    input_file: std.fs.File,
    output_file: std.fs.File,
    should_bye: bool,

    refiller: ReplRefiller,

    // TODO maybe save the runtime in this as a field
    pub fn init(self: *@This(), rt: *Runtime) !void {
        self.input_file = std.io.getStdIn();
        self.output_file = std.io.getStdOut();

        self.refiller.init();

        const external = External{
            .callback = externalsCallback,
            .userdata = self,
        };
        const wlidx = runtime.CompileState.interpret.toWordlistIndex() catch unreachable;
        try rt.defineExternal("bye", wlidx, @intFromEnum(ExternalId.bye));
        try rt.defineExternal("emit", wlidx, @intFromEnum(ExternalId.emit));
        try rt.defineExternal(".s", wlidx, @intFromEnum(ExternalId.showStack));
        try rt.defineExternal("key", wlidx, @intFromEnum(ExternalId.key));
        try rt.defineExternal("raw-mode", wlidx, @intFromEnum(ExternalId.rawMode));
        try rt.defineExternal("sqrt", wlidx, @intFromEnum(ExternalId.sqrt));
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
        rt.processBuffer(repl_start_file) catch |err| switch (err) {
            error.WordNotFound => {
                std.debug.print("Word not found: {s}\n", .{
                    rt.last_evaluated_word orelse unreachable,
                });
                return err;
            },
            else => return err,
        };

        rt.input_buffer.refiller = self.refiller.toRefiller();

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

    fn emit(self: *@This(), char: u8) !void {
        var bw = std.io.bufferedWriter(self.output_file.writer());
        try bw.writer().print("{c}", .{char});
        try bw.flush();
    }

    // TODO cleanup
    fn key(_: *@This()) !Cell {
        return 0;
    }

    // TODO cleanup
    fn rawMode(_: *@This(), _: bool) !void {
        return 0;
    }
};
