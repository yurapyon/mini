const std = @import("std");
const Allocator = std.mem.Allocator;

const mini = @import("mini");

const mem = mini.mem;

const kernel = mini.kernel;
const Kernel = kernel.Kernel;
const Cell = kernel.Cell;

const externals = mini.externals;
const External = externals.External;

const Handles = mini.utils.Handles;

// ===

// TODO
// dynmove
// saving and loading dynamic memory from file

pub const Dynamic = struct {
    allocator: Allocator,
    handles: *Handles,

    pub fn init(
        self: *@This(),
        allocator: Allocator,
        handles: *Handles,
    ) void {
        self.allocator = allocator;
        self.handles = handles;
    }

    // ===

    fn getMemoryFromHandle(self: *@This(), handle_id: Cell) !struct {
        ptr: *[]u8,
        slice: []u8,
    } {
        const any_ptr = self.handles.getHandlePtr(handle_id) orelse
            return error.InvalidHandleId;
        const ptr = @as(*[]u8, @ptrCast(@alignCast(any_ptr)));
        const slice = ptr.*;
        return .{
            .ptr = ptr,
            .slice = slice,
        };
    }

    fn getSliceFromHandle(self: *@This(), handle_id: Cell) ![]u8 {
        const m = try self.getMemoryFromHandle(handle_id);
        return m.slice;
    }

    fn getCellSliceFromHandle(self: *@This(), handle_id: Cell) ![]Cell {
        const m = try self.getMemoryFromHandle(handle_id);

        const cell_ptr = @as([*]Cell, @ptrCast(@alignCast(m.slice.ptr)));

        var cell_slice: []Cell = undefined;
        cell_slice.ptr = cell_ptr;
        cell_slice.len = m.slice.len / @sizeOf(Cell);

        return cell_slice;
    }

    fn allocateAndGetHandleId(self: *@This(), size: usize) External.Error!Cell {
        const slice = mem.allocate(
            self.allocator,
            size,
        ) catch return error.ExternalPanic;
        errdefer self.allocator.free(slice);

        const ptr = self.allocator.create([]u8) catch
            return error.ExternalPanic;
        errdefer self.allocator.destroy(ptr);

        ptr.* = slice;

        const handle_id = self.handles.getHandleForPtr(self.allocator, @ptrCast(ptr)) catch
            return error.ExternalPanic;

        return handle_id;
    }

    // ===

    fn allocate(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const dyn: *Dynamic = @ptrCast(@alignCast(userdata));

        try k.data_stack.assertWontUnderflow(1);

        const size = k.data_stack.popCell();
        const handle_id = try dyn.allocateAndGetHandleId(size);
        k.data_stack.pushCell(handle_id);
    }

    fn allocatePage(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const dyn: *Dynamic = @ptrCast(@alignCast(userdata));

        const handle_id = try dyn.allocateAndGetHandleId(mem.forth_memory_size);
        k.data_stack.pushCell(handle_id);
    }

    fn free(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const dyn: *Dynamic = @ptrCast(@alignCast(userdata));

        try k.data_stack.assertWontUnderflow(1);

        const handle_id = k.data_stack.popCell();

        const m = dyn.getMemoryFromHandle(handle_id) catch
            return error.ExternalPanic;

        dyn.allocator.free(m.slice);
        dyn.allocator.destroy(m.ptr);
        dyn.handles.freeHandle(dyn.allocator, handle_id);
    }

    fn reallocate(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const dyn: *Dynamic = @ptrCast(@alignCast(userdata));

        try k.data_stack.assertWontUnderflow(2);

        const handle_id = k.data_stack.popCell();
        const new_size = k.data_stack.popCell();

        const m = dyn.getMemoryFromHandle(handle_id) catch
            return error.ExternalPanic;
        const realloced_slice = dyn.allocator.realloc(m.slice, new_size) catch
            return error.ExternalPanic;
        m.ptr.* = realloced_slice;
    }

    fn dynSize(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const dyn: *Dynamic = @ptrCast(@alignCast(userdata));

        try k.data_stack.assertWontUnderflow(1);

        const handle_id = k.data_stack.popCell();

        const slice = dyn.getSliceFromHandle(handle_id) catch
            return error.ExternalPanic;

        k.data_stack.pushCell(@truncate(slice.len));
    }

    fn dynStore(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const dyn: *Dynamic = @ptrCast(@alignCast(userdata));

        try k.data_stack.assertWontUnderflow(3);

        const handle_id = k.data_stack.popCell();
        const addr = k.data_stack.popCell();
        const value = k.data_stack.popCell();

        const slice = dyn.getCellSliceFromHandle(handle_id) catch
            return error.ExternalPanic;

        try mem.assertCellAccess(addr);

        if (addr / 2 >= slice.len) {
            return error.OutOfBounds;
        }

        slice[addr / 2] = value;
    }

    fn dynPlusStore(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const dyn: *Dynamic = @ptrCast(@alignCast(userdata));

        try k.data_stack.assertWontUnderflow(3);

        const handle_id = k.data_stack.popCell();
        const addr = k.data_stack.popCell();
        const value = k.data_stack.popCell();

        const slice = dyn.getCellSliceFromHandle(handle_id) catch
            return error.ExternalPanic;

        try mem.assertCellAccess(addr);

        if (addr / 2 >= slice.len) {
            return error.OutOfBounds;
        }

        slice[addr / 2] +%= value;
    }

    fn dynFetch(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const dyn: *Dynamic = @ptrCast(@alignCast(userdata));

        try k.data_stack.assertWontUnderflow(2);

        const handle_id = k.data_stack.popCell();
        const addr = k.data_stack.popCell();

        const slice = dyn.getCellSliceFromHandle(handle_id) catch
            return error.ExternalPanic;

        try mem.assertCellAccess(addr);

        if (addr / 2 >= slice.len) {
            return error.OutOfBounds;
        }

        const value = slice[addr / 2];
        k.data_stack.pushCell(value);
    }

    fn dynStoreC(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const dyn: *Dynamic = @ptrCast(@alignCast(userdata));

        try k.data_stack.assertWontUnderflow(3);

        const handle_id = k.data_stack.popCell();
        const addr = k.data_stack.popCell();
        const value = k.data_stack.popCell();

        const slice = dyn.getSliceFromHandle(handle_id) catch
            return error.ExternalPanic;

        if (addr >= slice.len) {
            return error.OutOfBounds;
        }

        slice[addr] = @truncate(value);
    }

    fn dynPlusStoreC(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const dyn: *Dynamic = @ptrCast(@alignCast(userdata));

        try k.data_stack.assertWontUnderflow(3);

        const handle_id = k.data_stack.popCell();
        const addr = k.data_stack.popCell();
        const value = k.data_stack.popCell();

        const slice = dyn.getSliceFromHandle(handle_id) catch
            return error.ExternalPanic;

        if (addr >= slice.len) {
            return error.OutOfBounds;
        }

        slice[addr] +%= @truncate(value);
    }

    fn dynFetchC(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const dyn: *Dynamic = @ptrCast(@alignCast(userdata));

        try k.data_stack.assertWontUnderflow(2);

        const handle_id = k.data_stack.popCell();
        const addr = k.data_stack.popCell();

        const slice = dyn.getSliceFromHandle(handle_id) catch
            return error.ExternalPanic;

        if (addr >= slice.len) {
            return error.OutOfBounds;
        }

        const value = slice[addr];
        k.data_stack.pushCell(value);
    }

    fn toDyn(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const dyn: *Dynamic = @ptrCast(@alignCast(userdata));

        try k.data_stack.assertWontUnderflow(4);

        const count = k.data_stack.popCell();
        const handle_id = k.data_stack.popCell();
        const destination = k.data_stack.popCell();
        const source = k.data_stack.popCell();

        const dynamic_slice = dyn.getSliceFromHandle(handle_id) catch
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

    fn fromDyn(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const dyn: *Dynamic = @ptrCast(@alignCast(userdata));

        try k.data_stack.assertWontUnderflow(4);

        const count = k.data_stack.popCell();
        const destination = k.data_stack.popCell();
        const handle_id = k.data_stack.popCell();
        const source = k.data_stack.popCell();

        const dynamic_slice = dyn.getSliceFromHandle(handle_id) catch
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

    fn dynMove(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const dyn: *Dynamic = @ptrCast(@alignCast(userdata));

        try k.data_stack.assertWontUnderflow(5);

        const count = k.data_stack.popCell();
        const destination_id = k.data_stack.popCell();
        const destination = k.data_stack.popCell();
        const source_id = k.data_stack.popCell();
        const source = k.data_stack.popCell();

        // TODO
        _ = dyn;
        _ = count;
        _ = destination_id;
        _ = destination;
        _ = source_id;
        _ = source;
    }

    pub fn getExternals(self: *@This()) []const External {
        const exts = [_]External{
            .{
                .name = "allocate",
                .callback = allocate,
                .userdata = self,
            },
            .{
                .name = "allocate-page",
                .callback = allocatePage,
                .userdata = self,
            },
            .{
                .name = "free",
                .callback = free,
                .userdata = self,
            },
            .{
                .name = "reallocate",
                .callback = reallocate,
                .userdata = self,
            },
            .{
                .name = "dynsize",
                .callback = dynSize,
                .userdata = self,
            },
            .{
                .name = "dyn!",
                .callback = dynStore,
                .userdata = self,
            },
            .{
                .name = "dyn+!",
                .callback = dynPlusStore,
                .userdata = self,
            },
            .{
                .name = "dyn@",
                .callback = dynFetch,
                .userdata = self,
            },
            .{
                .name = "dync!",
                .callback = dynStoreC,
                .userdata = self,
            },
            .{
                .name = "dyn+c!",
                .callback = dynPlusStoreC,
                .userdata = self,
            },
            .{
                .name = "dync@",
                .callback = dynFetchC,
                .userdata = self,
            },
            .{
                .name = ">dyn",
                .callback = toDyn,
                .userdata = self,
            },
            .{
                .name = "dyn>",
                .callback = fromDyn,
                .userdata = self,
            },
            .{
                .name = "dynmove",
                .callback = dynMove,
                .userdata = self,
            },
        };

        return &exts;
    }
};
