const std = @import("std");

// ===

pub fn fillWithRandomBytes(slice: []u8) void {
    var xo = std.Random.Xoshiro256.init(0xdeadbeef);
    for (slice) |*value| {
        value.* = xo.random().int(u8);
    }
}

// NOTE
// Adapted from https://github.com/godotengine/godot/blob/63227bbc8ae5300319f14f8253c8158b846f355b/core/variant/array.cpp#L743
// pub fn shuffleSlice(comptime T: type, randomizer: std.Random, slice: []T) void {
//    var i = slice.len - 1;
//    while (i >= 1) {
//        const j = randomizer.int(usize) % (i + 1);
//
//        const temp = slice[i];
//        slice[i] = slice[j];
//        slice[j] = temp;
//
//        i -= 1;
//    }
//}
