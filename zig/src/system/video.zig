const c = @import("c.zig");

const runtime = @import("../runtime.zig");
const Cell = runtime.Cell;

const Pixels = @import("pixels.zig").Pixels;
const Characters = @import("characters.zig").Characters;

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

    pub fn init(self: *@This()) void {
        // self.clearBuffer();
        // self.updateTexture();

        self.pixels.init();
        self.characters.init();
    }

    pub fn deinit(_: *@This()) void {
        // TODO
    }

    // ===

    fn makeProgram(self: *@This()) void {
        _ = self;
        //         const vert_shader = gfx.shader.create(
        //             gfx.vert_shader_string,
        //             c.GL_VERTEX_SHADER,
        //         );
        //         defer gfx.shader.deinit(vert_shader);
        //
        //         const frag_shader = gfx.shader.create(
        //             gfx.frag_shader_string,
        //             c.GL_FRAGMENT_SHADER,
        //         );
        //         defer gfx.shader.deinit(frag_shader);
        //
        //         const program = gfx.program.create(vert_shader, frag_shader);
        //         self.program = program;
    }

    pub fn draw(self: *@This()) void {
        self.pixels.draw();
        self.characters.draw();
    }
};
