const std = @import("std");
// const Allocator = std.mem.Allocator;

const mem = @import("../memory.zig");

const kernel = @import("../kernel.zig");
const Kernel = kernel.Kernel;
const Cell = kernel.Cell;

const externals = @import("../externals.zig");
const External = externals.External;

// ===

// TODO
// dynmove
// saving and loading dynamic memory from file

fn getMemoryFromHandle(k: *Kernel, handle_id: Cell) !struct {
    ptr: *[]u8,
    slice: []u8,
} {
    const any_ptr = k.handles.getHandlePtr(handle_id) orelse
        return error.InvalidHandleId;
    const ptr = @as(*[]u8, @ptrCast(@alignCast(any_ptr)));
    const slice = ptr.*;
    return .{
        .ptr = ptr,
        .slice = slice,
    };
}

fn getSliceFromHandle(k: *Kernel, handle_id: Cell) ![]u8 {
    const m = try getMemoryFromHandle(k, handle_id);
    return m.slice;
}

fn getCellSliceFromHandle(k: *Kernel, handle_id: Cell) ![]Cell {
    const m = try getMemoryFromHandle(k, handle_id);

    const cell_ptr = @as([*]Cell, @ptrCast(@alignCast(m.slice.ptr)));

    var cell_slice: []Cell = undefined;
    cell_slice.ptr = cell_ptr;
    cell_slice.len = m.slice.len / @sizeOf(Cell);

    return cell_slice;
}

//

fn allocate(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const size = k.data_stack.popCell();

    const adj_size: usize = if (size == 0) mem.memory_size else size;
    const slice = k.allocator.allocWithOptions(
        u8,
        adj_size,
        std.mem.Alignment.fromByteUnits(@alignOf(Cell)),
        null,
    ) catch return error.ExternalPanic;
    errdefer k.allocator.free(slice);

    const ptr = k.allocator.create([]u8) catch
        return error.ExternalPanic;
    errdefer k.allocator.destroy(ptr);

    ptr.* = slice;

    const handle_id = k.handles.getHandleForPtr(@ptrCast(ptr)) catch
        return error.ExternalPanic;

    k.data_stack.pushCell(handle_id);
}

fn allocate0(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const slice = k.allocator.allocWithOptions(
        u8,
        0,
        std.mem.Alignment.fromByteUnits(@alignOf(Cell)),
        null,
    ) catch return error.ExternalPanic;
    errdefer k.allocator.free(slice);

    const ptr = k.allocator.create([]u8) catch
        return error.ExternalPanic;
    errdefer k.allocator.destroy(ptr);

    ptr.* = slice;

    const handle_id = k.handles.getHandleForPtr(@ptrCast(ptr)) catch
        return error.ExternalPanic;

    k.data_stack.pushCell(handle_id);
}

fn free(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const handle_id = k.data_stack.popCell();

    const m = getMemoryFromHandle(k, handle_id) catch
        return error.ExternalPanic;

    k.allocator.free(m.slice);
    k.allocator.destroy(m.ptr);
    k.handles.freeHandle(handle_id);
}

fn reallocate(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const handle_id = k.data_stack.popCell();
    const new_size = k.data_stack.popCell();

    const m = getMemoryFromHandle(k, handle_id) catch
        return error.ExternalPanic;
    const realloced_slice = k.allocator.realloc(m.slice, new_size) catch
        return error.ExternalPanic;
    m.ptr.* = realloced_slice;
}

fn dynStore(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const handle_id = k.data_stack.popCell();
    const addr = k.data_stack.popCell();
    const value = k.data_stack.popCell();

    const slice = getCellSliceFromHandle(k, handle_id) catch
        return error.ExternalPanic;

    try mem.assertCellAccess(addr);

    if (addr / 2 >= slice.len) {
        return error.OutOfBounds;
    }

    slice[addr / 2] = value;
}

fn dynPlusStore(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const handle_id = k.data_stack.popCell();
    const addr = k.data_stack.popCell();
    const value = k.data_stack.popCell();

    const slice = getCellSliceFromHandle(k, handle_id) catch
        return error.ExternalPanic;

    try mem.assertCellAccess(addr);

    if (addr / 2 >= slice.len) {
        return error.OutOfBounds;
    }

    slice[addr / 2] +%= value;
}

fn dynFetch(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const handle_id = k.data_stack.popCell();
    const addr = k.data_stack.popCell();

    const slice = getCellSliceFromHandle(k, handle_id) catch
        return error.ExternalPanic;

    try mem.assertCellAccess(addr);

    if (addr / 2 >= slice.len) {
        return error.OutOfBounds;
    }

    const value = slice[addr / 2];
    k.data_stack.pushCell(value);
}

fn dynStoreC(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const handle_id = k.data_stack.popCell();
    const addr = k.data_stack.popCell();
    const value = k.data_stack.popCell();

    const slice = getSliceFromHandle(k, handle_id) catch
        return error.ExternalPanic;

    if (addr >= slice.len) {
        return error.OutOfBounds;
    }

    slice[addr] = @truncate(value);
}

fn dynPlusStoreC(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const handle_id = k.data_stack.popCell();
    const addr = k.data_stack.popCell();
    const value = k.data_stack.popCell();

    const slice = getSliceFromHandle(k, handle_id) catch
        return error.ExternalPanic;

    if (addr >= slice.len) {
        return error.OutOfBounds;
    }

    slice[addr] +%= @truncate(value);
}

fn dynFetchC(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const handle_id = k.data_stack.popCell();
    const addr = k.data_stack.popCell();

    const slice = getSliceFromHandle(k, handle_id) catch
        return error.ExternalPanic;

    if (addr >= slice.len) {
        return error.OutOfBounds;
    }

    const value = slice[addr];
    k.data_stack.pushCell(value);
}

fn toDyn(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const count = k.data_stack.popCell();
    const handle_id = k.data_stack.popCell();
    const destination = k.data_stack.popCell();
    const source = k.data_stack.popCell();

    const dynamic_slice = getSliceFromHandle(k, handle_id) catch
        return error.ExternalPanic;

    // TODO calculating bounds like this is kindof messy
    const end_addr = @as(u32, destination) + @as(u32, count);

    if (end_addr >= dynamic_slice.len) {
        return error.OutOfBounds;
    }

    const source_slice = try mem.constSliceFromAddrAndLen(
        k.memory,
        source,
        count,
    );

    const destination_slice = dynamic_slice[destination..(destination + count)];

    @memcpy(destination_slice, source_slice);
}

fn fromDyn(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const count = k.data_stack.popCell();
    const destination = k.data_stack.popCell();
    const handle_id = k.data_stack.popCell();
    const source = k.data_stack.popCell();

    const dynamic_slice = getSliceFromHandle(k, handle_id) catch
        return error.ExternalPanic;

    // TODO calculating bounds like this is kindof messy
    const end_addr = @as(u32, source) + @as(u32, count);

    if (end_addr >= dynamic_slice.len) {
        return error.OutOfBounds;
    }

    const source_slice = dynamic_slice[source..(source + count)];

    const destination_slice = try mem.sliceFromAddrAndLen(
        k.memory,
        destination,
        count,
    );

    @memcpy(destination_slice, source_slice);
}

fn dynMove(k: *Kernel, _: ?*anyopaque) External.Error!void {
    _ = k;
    // TODO
}

pub fn registerExternals(k: *Kernel) !void {
    try k.addExternal("allocate", .{
        .callback = allocate,
        .userdata = null,
    });
    try k.addExternal("allocate0", .{
        .callback = allocate0,
        .userdata = null,
    });
    try k.addExternal("free", .{
        .callback = free,
        .userdata = null,
    });
    try k.addExternal("reallocate", .{
        .callback = reallocate,
        .userdata = null,
    });
    try k.addExternal("dyn!", .{
        .callback = dynStore,
        .userdata = null,
    });
    try k.addExternal("dyn+!", .{
        .callback = dynPlusStore,
        .userdata = null,
    });
    try k.addExternal("dyn@", .{
        .callback = dynFetch,
        .userdata = null,
    });
    try k.addExternal("dync!", .{
        .callback = dynStoreC,
        .userdata = null,
    });
    try k.addExternal("dyn+c!", .{
        .callback = dynPlusStoreC,
        .userdata = null,
    });
    try k.addExternal("dync@", .{
        .callback = dynFetchC,
        .userdata = null,
    });
    try k.addExternal(">dyn", .{
        .callback = toDyn,
        .userdata = null,
    });
    try k.addExternal("dyn>", .{
        .callback = fromDyn,
        .userdata = null,
    });
    try k.addExternal("dynmove", .{
        .callback = dynMove,
        .userdata = null,
    });
}
