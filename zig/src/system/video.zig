const std = @import("std");
const Allocator = std.mem.Allocator;

const c = @import("c.zig").c;

const kernel = @import("../kernel.zig");
const Cell = kernel.Cell;

const Pixels = @import("pixels.zig").Pixels;
const Characters = @import("characters.zig").Characters;
const Image = @import("image.zig").Image;
const ImageHandles = @import("image-handles.zig").ImageHandles;

// ===

// Inspired by pc-98
// 640x400, 4bit color, 24bit palette
// 80x25 character mode, 8bit "attributes" ie, blinking, reverse, etc and 16 color
//   7x11 characters, drawn in 8x16 boxes
// 80x40 character mode
//   7x9 characters, drawn in 8x10 boxes

// Character buffer on top of pixel buffer

// Note
// Pixel buffer isn't exposed to forth
//   pixel writes are done through pixelSet(x, y, color)-type
//     interfaces only
// Other buffers & palettes are directly accesible from forth

pub const screen_width = 640;
pub const screen_height = 400;

pub const Video = struct {
    image_handles: ImageHandles,

    pixels: Pixels,
    characters: Characters,

    handles: struct {
        screen: Cell,
        characters: Cell,
    },

    pub fn init(self: *@This(), allocator: Allocator) !void {
        try self.pixels.init(allocator);
        try self.characters.init(allocator);
        try self.image_handles.init(allocator);

        self.handles.screen = try self.image_handles.register(
            &self.pixels.image,
        );
        self.handles.characters = try self.image_handles.register(
            &self.characters.spritesheet,
        );
    }

    pub fn deinit(self: *@This()) void {
        self.characters.deinit();
        self.pixels.deinit();
        self.image_handles.deinit();
    }

    pub fn update(self: *@This()) void {
        self.pixels.update();
        self.characters.update();
    }

    pub fn draw(self: *@This()) void {
        c.glClear(c.GL_COLOR_BUFFER_BIT);
        self.pixels.draw();
        self.characters.draw();
    }

    pub fn getImage(self: *@This(), id: Cell) *Image {
        return self.image_handles.getPtr(id);
    }
};
