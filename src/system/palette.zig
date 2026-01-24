const mini = @import("mini");

const random = @import("utils/random.zig");

const c = @import("c.zig").c;

// ===

pub fn Palette(comptime color_ct: usize) type {
    return struct {
        pub const item_ct = color_ct * 3;

        colors: [item_ct]u8,

        pub fn init(self: *@This()) void {
            random.fillWithRandomBytes(&self.colors);
        }

        pub fn updateProgramUniforms(
            self: @This(),
            location: c.GLint,
        ) void {
            var float_colors = [_]f32{0} ** item_ct;
            for (self.colors, 0..) |byte, i| {
                float_colors[i] = @as(f32, @floatFromInt(byte)) / 255;
            }
            c.glUniform3fv(
                location,
                color_ct,
                &float_colors,
            );
        }
    };
}
