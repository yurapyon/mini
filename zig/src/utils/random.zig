pub fn fillWithRandomBytes(slice: []u8) void {
    const std = @import("std");
    var xo = std.Random.Xoshiro256.init(0xdeadbeef);
    for (slice) |*value| {
        value.* = xo.random().int(u8);
    }
}
