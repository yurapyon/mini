const std = @import("std");
const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;

const mini = @import("mini");

const mem = mini.mem;

const kernel = mini.kernel;
const Kernel = kernel.Kernel;
const Cell = kernel.Cell;

const externals = @import("externals.zig");
const External = externals.External;
const ExternalsList = externals.ExternalsList;

const Handles = mini.utils.Handles;

// ===

pub const Hashtables = struct {
    const Hashtable = AutoHashMap(Cell, Cell);

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

    fn getHashtableFromHandle(self: *@This(), handle_id: Cell) !*Hashtable {
        const any_ptr = self.handles.getHandlePtr(handle_id) orelse
            return error.InvalidHandleId;
        return @ptrCast(@alignCast(any_ptr));
    }

    fn allocateAndGetHandleId(self: *@This()) External.Error!Cell {
        const ht = self.allocator.create(Hashtable) catch return error.ExternalPanic;
        errdefer self.allocator.destroy(ht);

        ht.* = Hashtable.init(self.allocator);

        const handle_id = self.handles.getHandleForPtr(self.allocator, @ptrCast(ht)) catch
            return error.ExternalPanic;

        return handle_id;
    }

    // ===

    fn new(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const ht: *Hashtables = @ptrCast(@alignCast(userdata));
        const handle_id = try ht.allocateAndGetHandleId();
        k.data_stack.pushCell(handle_id);
    }

    fn delete(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        // TODO
        const ht: *Hashtables = @ptrCast(@alignCast(userdata));
        _ = ht;
        _ = k;

        //         try k.data_stack.assertWontUnderflow(1);
        //
        //         const handle_id = k.data_stack.popCell();
        //
        //         const m = dyn.getMemoryFromHandle(handle_id) catch
        //             return error.ExternalPanic;
        //
        //         dyn.allocator.free(m.slice);
        //         dyn.allocator.destroy(m.ptr);
        //         dyn.handles.freeHandle(dyn.allocator, handle_id);
    }

    fn store(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const ht: *Hashtables = @ptrCast(@alignCast(userdata));

        try k.data_stack.assertWontUnderflow(3);

        const handle_id = k.data_stack.popCell();
        const key = k.data_stack.popCell();
        const value = k.data_stack.popCell();

        const hashtable = ht.getHashtableFromHandle(handle_id) catch return error.ExternalPanic;
        hashtable.put(key, value) catch return error.ExternalPanic;
    }

    fn fetch(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const ht: *Hashtables = @ptrCast(@alignCast(userdata));

        try k.data_stack.assertWontUnderflow(2);

        const handle_id = k.data_stack.popCell();
        const key = k.data_stack.popCell();

        const hashtable = ht.getHashtableFromHandle(handle_id) catch return error.ExternalPanic;
        const value = hashtable.get(key);
        if (value) |v| {
            k.data_stack.pushCell(v);
            k.data_stack.pushBoolean(true);
        } else {
            k.data_stack.pushBoolean(false);
        }
    }

    fn has(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const ht: *Hashtables = @ptrCast(@alignCast(userdata));

        try k.data_stack.assertWontUnderflow(2);

        const handle_id = k.data_stack.popCell();
        const key = k.data_stack.popCell();

        const hashtable = ht.getHashtableFromHandle(handle_id) catch return error.ExternalPanic;
        const value = hashtable.contains(key);
        k.data_stack.pushBoolean(value);
    }

    pub fn pushExternals(self: *@This(), exts: *ExternalsList) !void {
        try exts.pushSlice(&.{
            .{
                .name = "ht.new",
                .callback = new,
                .userdata = self,
            },
            .{
                .name = "ht.delete",
                .callback = delete,
                .userdata = self,
            },
            .{
                .name = "ht!",
                .callback = store,
                .userdata = self,
            },
            .{
                .name = "ht@",
                .callback = fetch,
                .userdata = self,
            },
            .{
                .name = "ht.has?",
                .callback = has,
                .userdata = self,
            },
        });
    }

    pub fn getStartupFile(_: *@This()) []const u8 {
        return @embedFile("hashtables.mini.fth");
    }
};
