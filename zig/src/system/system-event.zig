const std = @import("std");
const Allocator = std.mem.Allocator;

const channel = @import("../utils/channel.zig");
const Queue = channel.Queue;

const kernel = @import("../kernel.zig");
const Cell = kernel.Cell;

// ===

pub const SystemEventTag = enum(Cell) {
    close,
    palette_store,
};

pub const SystemEvent = union(SystemEventTag) {
    close,
    palette_store: struct {
        addr: Cell,
        valus: Cell,
    },
};

pub const SystemChannel = struct {
    const system_event_count = 128;

    queue: Queue(SystemEvent),

    pub fn init(self: *@This(), allocator: Allocator) !void {
        try self.queue.init(allocator, system_event_count);
    }

    pub fn deinit(self: *@This()) void {
        self.queue.deinit();
    }

    pub fn push(self: *@This(), event: SystemEvent) !void {
        try self.queue.push(event);
    }

    pub fn pop(self: *@This()) ?SystemEvent {
        return self.queue.pop() catch null;
    }
};
