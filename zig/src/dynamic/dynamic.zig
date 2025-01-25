const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const runtime = @import("../runtime.zig");
const Cell = runtime.Cell;

// ===

// dynamic memory handles
// dyn@ dyn!

const Handle = struct {
    memory: ?[]u8,
};

pub const DynamicMemory = struct {
    allocator: Allocator,
    lookup: ArrayList(Handle),

    pub fn init(self: *@This(), allocator: Allocator) void {
        self.allocator = allocator;
        self.lookup = ArrayList(Handle).init(allocator);
    }

    pub fn deinit(self: *@This()) void {
        // TODO
        // free everything allocated with allocate() ?
        self.lookup.deinit();
    }

    fn getNextAvailableHandleId(self: *@This()) !Cell {
        var first_available_handle_id: ?Cell = null;

        for (self.lookup.items, 0..) |*handle, i| {
            if (handle.memory == null) {
                // NOTE
                // This intCast is okay as long as the only time Handles are added is
                //   below, after the check that the length is never > maxInt(Cell)
                first_available_handle_id = @intCast(i);
            }
        }

        if (first_available_handle_id) |handle_id| {
            return handle_id;
        } else {
            if (self.lookup.items.len > std.math.maxInt(Cell)) {
                // TODO error
                return error.TooManyHandles;
            }

            const handle_id: Cell = @intCast(self.lookup.items.len);
            _ = try self.lookup.addOne();
            return handle_id;
        }
    }

    fn freeHandle(self: *@This(), handle_id: Cell) void {
        if (handle_id == self.lookup.items.len - 1) {
            // TODO
            // can just resize the list
            // can also free all handles that are now unused from the end of the list
        } else {
            self.lookup.items[handle_id].memory = null;
        }
    }

    pub fn allocate(self: *@This(), size: usize) !Cell {
        const handle_id = try self.getNextAvailableHandleId();
        const handle = &self.lookup.items[handle_id];
        const memory = try self.allocator.alloc(u8, size);
        handle.memory = memory;
        return handle_id;
    }

    pub fn realloc(self: *@This(), handle_id: Cell, size: usize) !void {
        const handle = &self.lookup.items[handle_id];
        if (handle.memory) |memory| {
            const new_memory = try self.allocator.realloc(memory, size);
            handle.memory = new_memory;
        }
    }

    pub fn free(self: *@This(), handle_id: Cell) void {
        const memory = self.lookup.items[handle_id].memory;
        if (memory) |mem| {
            self.allocator.free(mem);
        }

        self.freeHandle(handle_id);
    }
};
