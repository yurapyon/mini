const std = @import("std");
const Allocator = std.mem.Allocator;

const kernel = @import("../kernel.zig");
const Cell = kernel.Cell;

const Handles = @import("../utils/handles.zig").Handles;

// ===

pub const Image = struct {
    width: Cell,
    height: Cell,
    data: []u8,
};

pub const Images = struct {
    allocator: Allocator,
    handles: Handles,

    pub fn init(self: *@This(), allocator: Allocator) void {
        self.allocator = allocator;
        self.handles.init(self.allocator);

        const id = self.createImage(100, 100) catch unreachable;
        self.freeImage(id) catch unreachable;
    }

    pub fn deinit(self: *@This()) void {
        // TODO free all images
        _ = self;
    }

    pub fn createImage(self: *@This(), width: Cell, height: Cell) !Cell {
        // TODO error handling
        const newImage = try self.allocator.create(Image);

        newImage.width = width;
        newImage.height = height;
        newImage.data = try self.allocator.alloc(u8, width * height);

        const id = try self.handles.getHandleForPtr(newImage);

        return id;
    }

    pub fn freeImage(self: *@This(), id: Cell) !void {
        const ptr = self.handles.getHandlePtr(id) orelse return error.ImageNotFound;
        const image: *Image = @ptrCast(@alignCast(ptr));
        self.allocator.free(image.data);
        self.allocator.destroy(image);
        self.handles.freeHandle(id);
    }
};
