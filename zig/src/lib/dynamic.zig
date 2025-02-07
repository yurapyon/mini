const std = @import("std");
const Allocator = std.mem.Allocator;

const mem = @import("../memory.zig");

const runtime = @import("../runtime.zig");
const Runtime = runtime.Runtime;
const Cell = runtime.Cell;
const ExternalError = runtime.ExternalError;

const externals = @import("../externals.zig");
const External = externals.External;

const dictionary = @import("../dictionary.zig");
const Dictionary = dictionary.Dictionary;

const Handles = @import("../utils/handles.zig").Handles;

// ===

const ExternalId = enum(Cell) {
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

    _max,
    _,
};

fn externalsCallback(rt: *Runtime, token: Cell, userdata: ?*anyopaque) External.Error!bool {
    const dyn = @as(*Dynamic, @ptrCast(@alignCast(userdata)));

    const external_id = @as(ExternalId, @enumFromInt(token - dyn.start_token));

    switch (external_id) {
        .allocate => {
            const size = rt.data_stack.pop();
            const handle_id = dyn.allocate(rt.allocator, size) catch {
                return error.ExternalPanic;
            };
            rt.data_stack.push(handle_id);
        },
        // TODO
        //         .realloc => {
        //             const size, const handle_id = rt.data_stack.pop2();
        //             dyn.dynamic_memory.realloc(handle_id, size) catch unreachable;
        //         },
        .free => {
            const handle_id = rt.data_stack.pop();
            dyn.free(rt.allocator, handle_id);
            dyn.handles.freeHandle(handle_id);
        },
        .dynFetch => {
            const handle_id, const addr = rt.data_stack.pop2();
            if (dyn.getAllocatedSlice(handle_id)) |slice| {
                const cell_ptr = @as([*]Cell, @alignCast(@ptrCast(slice.ptr)));
                const value = cell_ptr[addr / 2];
                rt.data_stack.push(value);
            }
        },
        .dynStore => {
            const handle_id, const addr = rt.data_stack.pop2();
            const value = rt.data_stack.pop();
            if (dyn.getAllocatedSlice(handle_id)) |slice| {
                const cell_ptr = @as([*]Cell, @alignCast(@ptrCast(slice.ptr)));
                cell_ptr[addr / 2] = value;
            }
        },
        .dynStoreAdd => {
            const handle_id, const addr = rt.data_stack.pop2();
            const value = rt.data_stack.pop();
            if (dyn.getAllocatedSlice(handle_id)) |slice| {
                const cell_ptr = @as([*]Cell, @alignCast(@ptrCast(slice.ptr)));
                cell_ptr[addr / 2] +%= value;
            }
        },
        .dynFetchC => {
            const handle_id, const addr = rt.data_stack.pop2();
            if (dyn.getAllocatedSlice(handle_id)) |slice| {
                const value = slice[addr];
                rt.data_stack.push(value);
            }
        },
        .dynStoreC => {
            const handle_id, const addr = rt.data_stack.pop2();
            const value = rt.data_stack.pop();
            if (dyn.getAllocatedSlice(handle_id)) |slice| {
                const u8_value: u8 = @truncate(value);
                slice[addr] = u8_value;
            }
        },
        .dynStoreAddC => {
            const handle_id, const addr = rt.data_stack.pop2();
            const value = rt.data_stack.pop();
            if (dyn.getAllocatedSlice(handle_id)) |slice| {
                const u8_value: u8 = @truncate(value);
                slice[addr] +%= u8_value;
            }
        },
        else => return false,
    }
    return true;
}

pub const Dynamic = struct {
    rt: *Runtime,
    start_token: Cell,
    handles: Handles,

    pub fn init(self: *@This(), rt: *Runtime) void {
        self.rt = rt;
        self.handles.init(rt.allocator);
    }

    pub fn initLibrary(self: *@This(), start_token: Cell) !Cell {
        const external = External{
            .callback = externalsCallback,
            .userdata = self,
        };
        const forth_vocabulary_addr = Dictionary.forth_vocabulary_addr;
        try self.rt.defineExternal(
            "allocate",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.allocate) + start_token,
        );
        try self.rt.defineExternal(
            "realloc",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.realloc) + start_token,
        );
        try self.rt.defineExternal(
            "free",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.free) + start_token,
        );
        try self.rt.defineExternal(
            "dyn@",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.dynFetch) + start_token,
        );
        try self.rt.defineExternal(
            "dyn!",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.dynStore) + start_token,
        );
        try self.rt.defineExternal(
            "dyn+!",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.dynStoreAdd) + start_token,
        );
        try self.rt.defineExternal(
            "dync@",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.dynFetchC) + start_token,
        );
        try self.rt.defineExternal(
            "dync!",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.dynStoreC) + start_token,
        );
        try self.rt.defineExternal(
            "dync+!",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.dynStoreAddC) + start_token,
        );
        try self.rt.addExternal(external);

        self.start_token = start_token;
        return @intFromEnum(ExternalId._max) + self.start_token;
    }

    fn allocate(self: *@This(), allocator: Allocator, size: Cell) !Cell {
        const adj_size: usize = if (size == 0) mem.memory_size else size;
        const slice = try allocator.allocWithOptions(
            u8,
            adj_size,
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
