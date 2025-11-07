const std = @import("std");
const Allocator = std.mem.Allocator;

const c = @import("c.zig").c;

const kernel = @import("../kernel.zig");
const Cell = kernel.Cell;

const Pixels = @import("pixels.zig").Pixels;
const Characters = @import("characters.zig").Characters;
const Images = @import("images.zig").Images;

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
    pixels: Pixels,
    characters: Characters,
    images: Images,

    pub fn init(self: *@This(), allocator: Allocator) !void {
        try self.pixels.init(allocator);
        self.characters.init();
        self.images.init(allocator);
    }

    pub fn deinit(self: *@This()) void {
        // TODO
        self.images.deinit();
        // characters
        self.pixels.deinit();
    }

    pub fn update(self: *@This()) void {
        self.pixels.update();
        self.characters.update();
    }

    pub fn draw(self: *@This()) void {
        c.glClear(c.GL_COLOR_BUFFER_BIT);
        self.pixels.draw();
        // self.characters.draw();
    }

    pub fn copyImageToScreen(
        self: *@This(),
        image_id: Cell,
        ix: Cell,
        iy: Cell,
        sx: Cell,
        sy: Cell,
        w: Cell,
        h: Cell,
    ) void {
        _ = self;
        _ = image_id;
        _ = ix;
        _ = iy;
        _ = sx;
        _ = sy;
        _ = w;
        _ = h;
    }
};
