const runtime = @import("../runtime.zig");
const Cell = runtime.Cell;

// 5x7 characters, drawn with 1px right and bottom border
const Character = [5]u8;
// 256 color palette with 24bit color
const RGB = [3]u8;

pub const Video = struct {
    // 64k * 3 can max 512 x 384 x 8bit
    // This could fit a 400x300 drawing canvas
    buffer: [64 * 1024 * 3]u8,
    character_map: [256]Character,
    palette: [256]RGB,

    pub fn init(self: *@This()) void {
        self.mode = .Character;
    }

    pub fn putCharacter(self: *@This(), x: Cell, y: Cell, char: u8) void {
        _ = self;
        _ = x;
        _ = y;
        _ = char;
    }

    pub fn putPixel(self: *@This(), x: Cell, y: Cell, color: u8) void {
        _ = self;
        _ = x;
        _ = y;
        _ = color;
    }

    pub fn blit(
        self: *@This(),
        x: Cell,
        y: Cell,
        w: Cell,
        h: Cell,
        colors: []u8,
        mask: []u8,
    ) void {
        _ = self;
        _ = x;
        _ = y;
        _ = w;
        _ = h;
        _ = colors;
        _ = mask;
    }

    pub fn swapBuffers(self: *@This()) void {
        _ = self;
    }
};
