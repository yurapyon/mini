const runtime = @import("../runtime.zig");
const Cell = runtime.Cell;

const VideoMode = enum {
    Character,
};

const Character = [5]u8;

pub const Video = struct {
    // 64k can support 400 x 300 with 4 bit color
    // this is 66 x 37 characters
    ram: [64 * 1024]u8,
    mode: VideoMode,
    character_map: [256]Character,

    pub fn init(self: *@This()) void {
        self.mode = .Character;
    }

    pub fn putCharacter(self: *@This(), x: Cell, y: Cell, char: u8) void {
        _ = self;
        _ = x;
        _ = y;
        _ = char;
    }
};
