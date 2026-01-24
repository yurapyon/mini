const std = @import("std");

// ===

pub fn fillWithRandomBytes(slice: []u8) void {
    var xo = std.Random.Xoshiro256.init(0xdeadbeef);
    for (slice) |*value| {
        value.* = xo.random().int(u8);
    }
}
