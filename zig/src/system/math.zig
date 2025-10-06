const kernel = @import("../kernel.zig");
const Cell = kernel.Cell;

pub const m3 = struct {
    pub const Mat3 = [9]f32;

    // column major
    // m3[x * 3 + y]
    const m_00 = 0 * 3 + 0;
    const m_01 = 0 * 3 + 1;
    const m_02 = 0 * 3 + 2;
    const m_10 = 1 * 3 + 0;
    const m_11 = 1 * 3 + 1;
    const m_12 = 1 * 3 + 2;
    const m_20 = 2 * 3 + 0;
    const m_21 = 2 * 3 + 1;
    const m_22 = 2 * 3 + 2;

    pub fn zero(mat3: *Mat3) void {
        for (mat3) |*f| {
            f.* = 0;
        }
    }

    pub fn identity(mat3: *Mat3) void {
        zero(mat3);
        mat3[m_00] = 1;
        mat3[m_11] = 1;
        mat3[m_22] = 1;
    }

    pub fn orthoScreen(mat3: *Mat3, width: Cell, height: Cell) void {
        identity(mat3);
        // scale
        mat3[m_00] = 2 / @as(f32, @floatFromInt(width));
        mat3[m_11] = -2 / @as(f32, @floatFromInt(height));
        // translate
        mat3[m_20] = -1;
        mat3[m_21] = 1;
    }

    pub fn scaling(mat3: *Mat3, x: f32, y: f32) void {
        identity(mat3);
        mat3[m_00] = x;
        mat3[m_11] = y;
    }

    pub fn mult(out: *Mat3, other: Mat3) void {
        var temp: Mat3 = undefined;
        temp[m_00] = out[m_00] * other[m_00] +
            out[m_01] * other[m_10] + out[m_02] * other[m_20];
        temp[m_01] = out[m_00] * other[m_01] +
            out[m_01] * other[m_11] + out[m_02] * other[m_21];
        temp[m_02] = out[m_00] * other[m_02] +
            out[m_01] * other[m_12] + out[m_02] * other[m_22];
        temp[m_10] = out[m_10] * other[m_00] +
            out[m_11] * other[m_10] + out[m_12] * other[m_20];
        temp[m_11] = out[m_10] * other[m_01] +
            out[m_11] * other[m_11] + out[m_12] * other[m_21];
        temp[m_12] = out[m_10] * other[m_02] +
            out[m_11] * other[m_12] + out[m_12] * other[m_22];
        temp[m_20] = out[m_20] * other[m_00] +
            out[m_21] * other[m_10] + out[m_22] * other[m_20];
        temp[m_21] = out[m_20] * other[m_01] +
            out[m_21] * other[m_11] + out[m_22] * other[m_21];
        temp[m_22] = out[m_20] * other[m_02] +
            out[m_21] * other[m_12] + out[m_22] * other[m_22];
        for (temp, 0..) |f, i| {
            out[i] = f;
        }
    }
};
