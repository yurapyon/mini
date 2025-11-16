const std = @import("std");
// const Allocator = std.mem.Allocator;

const mem = @import("../memory.zig");

const kernel = @import("../kernel.zig");
const Kernel = kernel.Kernel;
const Cell = kernel.Cell;

const externals = @import("../externals.zig");
const External = externals.External;

// ===

fn getMemoryFromHandle(k: *Kernel, handle_id: Cell) ?struct {
    ptr: *[]u8,
    slice: []u8,
} {
    const any_ptr = k.handles.getHandlePtr(handle_id) orelse return null;
    const ptr = @as(*[]u8, @ptrCast(@alignCast(any_ptr)));
    const slice = ptr.*;
    return .{
        .ptr = ptr,
        .slice = slice,
    };
}

fn getSliceFromHandle(k: *Kernel, handle_id: Cell) ?[]u8 {
    const m = getMemoryFromHandle(k, handle_id) orelse return null;
    return m.slice;
}

fn getCellSliceFromHandle(k: *Kernel, handle_id: Cell) ?[]Cell {
    const m = getMemoryFromHandle(k, handle_id) orelse return null;

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

fn free(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const handle_id = k.data_stack.popCell();

    const memory = getMemoryFromHandle(k, handle_id);
    if (memory) |m| {
        k.allocator.free(m.slice);
        k.allocator.destroy(m.ptr);
        k.handles.freeHandle(handle_id);
    }
}

fn reallocate(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const handle_id = k.data_stack.popCell();
    const new_size = k.data_stack.popCell();

    const memory = getMemoryFromHandle(k, handle_id);
    if (memory) |m| {
        const realloced_slice = k.allocator.realloc(m.slice, new_size) catch
            return error.ExternalPanic;
        m.ptr.* = realloced_slice;
    }
}

fn dynStore(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const handle_id = k.data_stack.popCell();
    const addr = k.data_stack.popCell();
    const value = k.data_stack.popCell();

    const slice = getCellSliceFromHandle(k, handle_id);

    if (slice) |slc| {
        // TODO test length
        // TODO check alignment
        slc[addr / 2] = value;
    }
}

fn dynFetch(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const handle_id = k.data_stack.popCell();
    const addr = k.data_stack.popCell();

    const slice = getCellSliceFromHandle(k, handle_id);

    if (slice) |slc| {
        // TODO test length
        // TODO check alignment
        const value = slc[addr / 2];
        k.data_stack.pushCell(value);
    } else {
        // TODO what to do here?
        k.data_stack.pushCell(0);
    }
}

pub fn registerExternals(k: *Kernel) !void {
    try k.addExternal("allocate", .{
        .callback = allocate,
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
    try k.addExternal("dyn@", .{
        .callback = dynFetch,
        .userdata = null,
    });
}
