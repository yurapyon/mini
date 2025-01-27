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

const ReplRefiller = @import("repl_refiller.zig").ReplRefiller;

const Handles = @import("../memory/handles.zig").Handles;

// ===

const ExternalId = enum(Cell) {
    bye = 64,
    emit,
    dot,
    showStack,
    log,
    key,
    rawMode,

    allocate,
    realloc,
    free,
    dynFetch,
    dynStore,
    dynStoreAdd,
    dynFetchC,
    dynStoreC,
    dynStoreAddC,
    // TODO
    // dynMove
    // copy allocated memory to/from dictionary
    // read file into dynamic memory
    _,
};

const repl_file = @embedFile("repl.mini.fth");

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
        .dot => {
            const cell = rt.data_stack.pop();
            repl.dot(cell) catch return error.ExternalPanic;
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
        .log => {
            const base, const x = rt.data_stack.pop2();
            if (base < 1 or x < 0) {
                rt.data_stack.push(0);
            }
            const log_x = std.math.log(Cell, base, x);
            rt.data_stack.push(log_x);
        },
        .key => {},
        .allocate => {
            const size = rt.data_stack.pop();
            // TODO dont catch unreachable
            const handle_id = repl.allocate(rt.allocator, size) catch unreachable;
            rt.data_stack.push(handle_id);
        },
        //         .realloc => {
        //             const size, const handle_id = rt.data_stack.pop2();
        //             repl.dynamic_memory.realloc(handle_id, size) catch unreachable;
        //         },
        .free => {
            const handle_id = rt.data_stack.pop();
            repl.free(rt.allocator, handle_id);
            repl.handles.freeHandle(handle_id);
        },
        .dynFetch => {
            const handle_id, const addr = rt.data_stack.pop2();
            if (repl.getAllocatedSlice(handle_id)) |slice| {
                const cell_ptr = @as([*]Cell, @alignCast(@ptrCast(slice.ptr)));
                const value = cell_ptr[addr / 2];
                rt.data_stack.push(value);
            }
        },
        .dynStore => {
            const handle_id, const addr = rt.data_stack.pop2();
            const value = rt.data_stack.pop();
            if (repl.getAllocatedSlice(handle_id)) |slice| {
                const cell_ptr = @as([*]Cell, @alignCast(@ptrCast(slice.ptr)));
                cell_ptr[addr / 2] = value;
            }
        },
        .dynStoreAdd => {
            const handle_id, const addr = rt.data_stack.pop2();
            const value = rt.data_stack.pop();
            if (repl.getAllocatedSlice(handle_id)) |slice| {
                const cell_ptr = @as([*]Cell, @alignCast(@ptrCast(slice.ptr)));
                cell_ptr[addr / 2] +%= value;
            }
        },
        .dynFetchC => {
            const handle_id, const addr = rt.data_stack.pop2();
            if (repl.getAllocatedSlice(handle_id)) |slice| {
                const value = slice[addr];
                rt.data_stack.push(value);
            }
        },
        .dynStoreC => {
            const handle_id, const addr = rt.data_stack.pop2();
            const value = rt.data_stack.pop();
            if (repl.getAllocatedSlice(handle_id)) |slice| {
                const u8_value: u8 = @truncate(value);
                slice[addr] = u8_value;
            }
        },
        .dynStoreAddC => {
            const handle_id, const addr = rt.data_stack.pop2();
            const value = rt.data_stack.pop();
            if (repl.getAllocatedSlice(handle_id)) |slice| {
                const u8_value: u8 = @truncate(value);
                slice[addr] +%= u8_value;
            }
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

    handles: Handles,

    // TODO maybe save the runtime in this as a field
    pub fn init(self: *@This(), rt: *Runtime) !void {
        self.input_file = std.io.getStdIn();
        self.output_file = std.io.getStdOut();

        self.refiller.init();

        self.handles.init(rt.allocator);

        const external = External{
            .callback = externalsCallback,
            .userdata = self,
        };
        const wlidx = runtime.CompileState.interpret.toWordlistIndex() catch unreachable;
        try rt.defineExternal("bye", wlidx, @intFromEnum(ExternalId.bye));
        try rt.defineExternal("emit", wlidx, @intFromEnum(ExternalId.emit));
        try rt.defineExternal(".", wlidx, @intFromEnum(ExternalId.dot));
        try rt.defineExternal(".s", wlidx, @intFromEnum(ExternalId.showStack));
        try rt.defineExternal("log", wlidx, @intFromEnum(ExternalId.log));
        try rt.defineExternal("key", wlidx, @intFromEnum(ExternalId.key));
        try rt.defineExternal("raw-mode", wlidx, @intFromEnum(ExternalId.rawMode));
        try rt.defineExternal("allocate", wlidx, @intFromEnum(ExternalId.allocate));
        try rt.defineExternal("realloc", wlidx, @intFromEnum(ExternalId.realloc));
        try rt.defineExternal("free", wlidx, @intFromEnum(ExternalId.free));
        try rt.defineExternal("dyn@", wlidx, @intFromEnum(ExternalId.dynFetch));
        try rt.defineExternal("dyn!", wlidx, @intFromEnum(ExternalId.dynStore));
        try rt.defineExternal("dyn+!", wlidx, @intFromEnum(ExternalId.dynStoreAdd));
        try rt.defineExternal("dync@", wlidx, @intFromEnum(ExternalId.dynFetchC));
        try rt.defineExternal("dync!", wlidx, @intFromEnum(ExternalId.dynStoreC));
        try rt.defineExternal("dync+!", wlidx, @intFromEnum(ExternalId.dynStoreAddC));
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
        rt.input_buffer.refiller = self.refiller.toRefiller();

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

    // TODO cleanup
    fn key(_: *@This()) !Cell {
        return 0;
    }

    // TODO cleanup
    fn rawMode(_: *@This(), _: bool) !void {
        return 0;
    }

    fn allocate(self: *@This(), allocator: Allocator, size: Cell) !Cell {
        const slice = try allocator.allocWithOptions(
            u8,
            size,
            @alignOf(Cell),
            null,
        );
        const ptr = try allocator.create([]u8);
        ptr.* = slice;
        const handle_id = try self.handles.getHandleForPtr(@ptrCast(ptr));
        return handle_id;
    }

    fn getAllocatedSlice(self: *@This(), handle_id: Cell) ?[]u8 {
        const maybe_any_ptr = self.handles.getHandlePtr(handle_id);
        if (maybe_any_ptr) |any_ptr| {
            const ptr = @as(*[]u8, @ptrCast(@alignCast(any_ptr)));
            const slice = ptr.*;
            return slice;
        }
        return null;
    }

    fn free(self: *@This(), allocator: Allocator, handle_id: Cell) void {
        const maybe_any_ptr = self.handles.getHandlePtr(handle_id);
        if (maybe_any_ptr) |any_ptr| {
            const ptr = @as(*[]u8, @ptrCast(@alignCast(any_ptr)));
            const slice = ptr.*;
            allocator.free(slice);
            allocator.destroy(ptr);
        }
    }
};
