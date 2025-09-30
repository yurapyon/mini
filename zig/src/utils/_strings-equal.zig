const std = @import("std");

/// Case insensitive string compare
pub fn stringsEqual(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) {
        return false;
    }

    for (a, b) |a_ch, b_ch| {
        if (std.ascii.toLower(a_ch) != std.ascii.toLower(b_ch)) {
            return false;
        }
    }

    return true;
}

test "string compare" {
    const testing = std.testing;

    try testing.expect(stringsEqual("asdf", "asdf"));
    try testing.expect(stringsEqual("asdf", "Asdf"));
    try testing.expect(!stringsEqual("asdf ", "asdf"));
}
