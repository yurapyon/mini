const std = @import("std");
const Allocator = std.mem.Allocator;

const runtime = @import("../runtime.zig");
const Runtime = runtime.Runtime;
const Cell = runtime.Cell;
const ExternalError = runtime.ExternalError;

const mem = @import("../memory.zig");

const bytecodes = @import("../bytecodes.zig");

const externals = @import("../externals.zig");
const External = externals.External;

const dictionary = @import("../dictionary.zig");
const Dictionary = dictionary.Dictionary;

const Refiller = @import("../refiller.zig").Refiller;

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
});

// ===

const ExternalId = enum(Cell) {
    bye = bytecodes.bytecodes_count,
    emit,
    showStack,
    key,
    rawMode,
    sqrt,
    sleep,
    sleepS,
    time,
    shell,
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
            try bytecodes.quit(rt);
            repl.should_bye = true;
        },
        .emit => {
            const raw_char = rt.data_stack.popCell();
            const char = @as(u8, @truncate(raw_char & 0xff));
            repl.emit(char) catch return error.ExternalPanic;
        },
        .showStack => {
            // TODO
            // something about this is broken
            const count = rt.data_stack.popCell();
            const u8_count: u8 = @truncate(count);
            std.debug.print("<{d}>", .{u8_count});

            var i: u8 = 0;
            while (i < u8_count) : (i += 1) {
                // TODO
                // std.debug.print(" {d}", .{rt.data_stack.index(i)});
            }
        },
        .key => {},
        .rawMode => {},
        .sqrt => {
            const value = rt.data_stack.popCell();
            const sqrt_value = std.math.sqrt(value);
            rt.data_stack.pushCell(sqrt_value);
        },
        .sleep => {
            const value: u64 = rt.data_stack.popCell();
            std.time.sleep(value * 1000000);
        },
        .sleepS => {
            const value: u64 = rt.data_stack.popCell();
            std.time.sleep(value * 1000000000);
        },
        .time => {
            const timestamp = std.time.timestamp();
            const seconds = @rem(timestamp, 60);
            const minutes = @rem(@divFloor(timestamp, 60), 60);
            const hours = @rem(@divFloor(timestamp, 3600), 24);
            rt.data_stack.pushCell(@intCast(hours));
            rt.data_stack.pushCell(@intCast(minutes));
            rt.data_stack.pushCell(@intCast(seconds));
        },
        .shell => {
            const len = rt.data_stack.popCell();
            const addr = rt.data_stack.popCell();
            const command = try mem.constSliceFromAddrAndLen(
                rt.memory,
                addr,
                len,
            );
            // TODO don't catch unreachable
            const temp = rt.allocator.alloc(u8, len + 1) catch unreachable;
            std.mem.copyForwards(u8, temp, command);
            temp[len] = 0;
            _ = c.system(temp.ptr);
        },
        else => return false,
    }
    return true;
}

pub const Repl = struct {
    input_file: std.fs.File,
    output_file: std.fs.File,
    should_bye: bool,

    // TODO maybe save the runtime in this as a field
    pub fn init(self: *@This(), rt: *Runtime) !void {
        self.input_file = std.io.getStdIn();
        self.output_file = std.io.getStdOut();

        const external = External{
            .callback = externalsCallback,
            .userdata = self,
        };
        const forth_vocabulary_addr = Dictionary.forth_vocabulary_addr;
        try rt.defineExternal(
            "bye",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.bye),
        );
        try rt.defineExternal(
            "emit",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.emit),
        );
        try rt.defineExternal(
            ".s",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.showStack),
        );
        try rt.defineExternal(
            "key",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.key),
        );
        try rt.defineExternal(
            "raw-mode",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.rawMode),
        );
        try rt.defineExternal(
            "sqrt",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.sqrt),
        );
        try rt.defineExternal(
            "sleep",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.sleep),
        );
        try rt.defineExternal(
            "sleeps",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.sleepS),
        );
        try rt.defineExternal(
            "time-utc",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.time),
        );
        try rt.defineExternal(
            "shell",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.shell),
        );
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

        rt.input_buffer.refiller = self.toRefiller();

        self.should_bye = false;

        while (!self.should_bye) {
            rt.interpretUntilQuit() catch |err| switch (err) {
                error.WordNotFound => {
                    std.debug.print(">> {s}?\n", .{
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

    fn refill(self_: ?*anyopaque, out: []u8) !?usize {
        const self: *@This() = @ptrCast(@alignCast(self_));

        const reader = self.input_file.reader();
        const slice =
            reader.readUntilDelimiterOrEof(
            out[0..out.len],
            '\n',
        ) catch return error.CannotRefill;
        if (slice) |slc| {
            return slc.len;
        } else {
            return null;
        }
    }

    pub fn toRefiller(self: *@This()) Refiller {
        return .{
            .callback = refill,
            .userdata = self,
        };
    }
};
