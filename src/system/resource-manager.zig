const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const mini = @import("mini");

const kernel = mini.kernel;
const Cell = kernel.Cell;

const Handles = mini.utils.Handles;

const Image = @import("image.zig").Image;
const Timer = @import("timer.zig").Timer;

// ===

// NOTE
// The resource manager is not thread-safe
//   For now this is okay, but in the future it may be good to fix that

pub const Resource = union(enum) {
    image: *Image,
    timer: *Timer,
};

pub const ResourceManager = struct {
    allocator: Allocator,
    handles: *Handles,
    resources: ArrayList(*Resource),

    pub fn init(
        self: *@This(),
        allocator: Allocator,
        handles: *Handles,
    ) !void {
        self.allocator = allocator;
        self.handles = handles;
        self.resources = .empty;
    }

    pub fn deinit(self: *@This()) void {
        // TODO deinit and free all resources
        _ = self;
    }

    fn createResource(self: *@This()) !struct {
        resource: *Resource,
        handle: Cell,
    } {
        const resource = try self.allocator.create(Resource);
        errdefer self.allocator.destroy(resource);

        try self.resources.append(self.allocator, resource);
        errdefer _ = self.resources.pop();

        const handle = try self.handles.getHandleForPtr(self.allocator, resource);

        return .{
            .resource = resource,
            .handle = handle,
        };
    }

    fn freeResource(self: *@This(), resource: *Resource) void {
        _ = self;
        _ = resource;
        // const resource = self.handles.getHandlePtr(id);

        // self.handles.freeHandle(id);

        // var index: ?usize = null;
        // for (0..self.resource.items.len) |i| {
        // if (self.resource.items[i] == resource) {
        // index = i;
        // break;
        // }
        // }
        //
        // if (index) |idx| {
        // _ = self.created_images.swapRemove(idx);
        // } else {
        // // TODO
        // // handle image not found
        // }
        //
        // image.deinit(self.allocator);
        // self.allocator.destroy(image);
    }

    pub fn register(self: *@This(), resource: *Resource) !Cell {
        const handle = try self.handles.getHandleForPtr(self.allocator, resource);
        return handle;
    }

    pub fn createImage(self: *@This(), width: Cell, height: Cell) !Cell {
        const r = try self.createResource();
        errdefer self.freeResource(r.resource);

        const image = try self.allocator.create(Image);
        errdefer self.allocator.destroy(image);

        try image.init(self.allocator, width, height);

        r.resource.* = .{ .image = image };

        return r.handle;
    }

    pub fn createTimer(self: *@This()) !Cell {
        const r = try self.createResource();
        errdefer self.freeResource(r.resource);

        const timer = try self.allocator.create(Timer);
        errdefer self.allocator.destroy(timer);
        timer.init();

        r.resource.* = .{ .timer = timer };

        return r.handle;
    }

    pub fn getResource(self: *@This(), id: Cell) !*Resource {
        const ptr = self.handles.getHandlePtr(id);

        if (ptr) |p| {
            return @ptrCast(@alignCast(p));
        } else {
            return error.ResourceNotFound;
        }
    }

    pub fn getImage(self: *@This(), id: Cell) !*Image {
        const resource = try self.getResource(id);
        switch (resource.*) {
            .image => |image| return image,
            else => {
                return error.NotAnImage;
            },
        }
    }

    pub fn getTimer(self: *@This(), id: Cell) !*Timer {
        const resource = try self.getResource(id);
        switch (resource.*) {
            .timer => |timer| return timer,
            else => {
                return error.NotATimer;
            },
        }
    }
};
