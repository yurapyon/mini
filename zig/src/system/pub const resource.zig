const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const kernel = @import("../kernel.zig");
const Cell = kernel.Cell;

const Handles = @import("../utils/handles.zig").Handles;

const Image = @import("image.zig").Image;
const Timer = @import("timer.zig").Timer;

// ===

pub const Resource = union(enum) {
    image: *Image,
    timer: *Timer,
};

pub const ResourceManager = struct {
    allocator: Allocator,
    handles: Handles,
    resources: ArrayList(Resource),

    pub fn init(self: *@This(), allocator: Allocator) !void {
        self.allocator = allocator;
        self.handles.init(allocator);
        self.resources = .empty;
    }

    pub fn deinit(self: *@This()) void {
        // TODO deinit and free all resources
        self.handles.deinit();
    }

    pub fn createImage(self: *@This(), width: Cell, height: Cell) !Cell {
        const image = try self.allocator.create(Image);
        errdefer self.allocator.destroy(image);

        try image.init(self.allocator, width, height);
        errdefer image.deinit(self.allocator);

        try self.resources.append(self.allocator, .{ .image = image });
        errdefer _ = self.resources.pop();

        return try self.register(image);
    }

    pub fn free(self: *@This(), id: Cell) void {
        const image = self.getPtr(id);

        self.handles.freeHandle(id);

        var index: ?usize = null;
        for (0..self.created_images.items.len) |i| {
            if (self.created_images.items[i] == image) {
                index = i;
                break;
            }
        }

        if (index) |idx| {
            _ = self.created_images.swapRemove(idx);
        } else {
            // TODO
            // handle image not found
        }

        image.deinit(self.allocator);
        self.allocator.destroy(image);
    }

    pub fn register(self: *@This(), image: *Image) !Cell {
        const handle = try self.handles.getHandleForPtr(image);
        return handle;
    }

    pub fn getPtr(self: *@This(), id: Cell) *Image {
        return @ptrCast(@alignCast(self.handles.getHandlePtr(id)));
    }
};
