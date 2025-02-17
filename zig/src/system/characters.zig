const c = @import("c.zig");

const runtime = @import("../runtime.zig");
const Cell = runtime.Cell;

pub const Characters = struct {
    palette: [8 * 3]u8,
    sprites: [256 * 10]u8,
    buffer: [80 * 40 * 2]u8,

    pub fn init(self: *@This()) void {
        _ = self;
    }

    pub fn draw(self: *@This()) void {
        _ = self;
    }

    pub fn store(self: *@This(), addr: Cell, value: u8) void {
        const break0 = @sizeOf(self.palette);
        const break1 = break0 + @sizeOf(self.sprites);
        const break2 = break1 + @sizeOf(self.buffer);
        if (addr < break0) {
            self.palette[addr] = value;
        } else if (addr < break1) {
            self.sprites[addr - break0] = value;
        } else if (addr < break2) {
            self.buffer[addr - break1] = value;
        }
    }

    pub fn fetch(self: *@This(), addr: Cell) u8 {
        const break0 = @sizeOf(self.palette);
        const break1 = break0 + @sizeOf(self.sprites);
        const break2 = break1 + @sizeOf(self.buffer);
        if (addr < break0) {
            return self.palette[addr];
        } else if (addr < break1) {
            return self.sprites[addr - break0];
        } else if (addr < break2) {
            return self.buffer[addr - break1];
        }
    }

    //     pub fn putCharacter(
    //         self: *@This(),
    //         x: Cell,
    //         y: Cell,
    //         character_idx: u8,
    //         palette_idx: u8,
    //     ) void {
    //         const character = self.characters[character_idx];
    //         const color = self.palette[palette_idx];
    //
    //         for (0..6) |i| {
    //             // TODO maybe do scr_w and scr_h adjustment in forth
    //             const at_x = x + i + (screen_width - 400) / 2;
    //             var col = character[i];
    //
    //             for (0..8) |j| {
    //                 const at_y = y + j + (screen_height - 300) / 2;
    //                 const value = col & 0x80;
    //
    //                 if (value != 0) {
    //                     const buffer_at = at_x + at_y * screen_width;
    //                     self.buffer[buffer_at] = color;
    //                 }
    //
    //                 col <<= 1;
    //             }
    //         }
    //     }

};
