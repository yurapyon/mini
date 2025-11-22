const std = @import("std");
const Allocator = std.mem.Allocator;

const channel = @import("../utils/channel.zig");
const Queue = channel.Queue;

const kernel = @import("../kernel.zig");
const Cell = kernel.Cell;

// ===

pub const InputEventTag = enum(Cell) {
    key,
    mouse_position,
    mouse_button,
    char,
    should_close = 16,
};

pub const InputEvent = union(InputEventTag) {
    key: struct {
        keycode: c_int,
        scancode: c_int,
        action: c_int,
        mods: c_int,
    },
    mouse_position: struct {
        x: f64,
        y: f64,
    },
    mouse_button: struct {
        button: c_int,
        action: c_int,
        mods: c_int,
    },
    char: struct {
        codepoint: c_uint,
    },
    should_close: bool,
};

pub const InputChannel = struct {
    const input_event_count = 128;

    queue: Queue(InputEvent),

    pub fn init(self: *@This(), allocator: Allocator) !void {
        try self.queue.init(allocator, input_event_count);
    }

    pub fn deinit(self: *@This()) void {
        self.queue.deinit();
    }

    pub fn push(self: *@This(), event: InputEvent) !void {
        try self.queue.push(event);
    }

    pub fn pop(self: *@This()) ?InputEvent {
        return self.queue.pop() catch null;
    }
};
