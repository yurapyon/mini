const std = @import("std");

pub const ParseNumberError = error{
    InvalidNumber,
    InvalidBase,
    Overflow,
};

pub fn parseNumber(str: []const u8, base: usize) ParseNumberError!usize {
    if (base < 1 or base > 36) {
        return error.InvalidBase;
    }

    if (str.len == 0) {
        if (base == 1) {
            return 0;
        } else {
            return error.InvalidNumber;
        }
    }

    var is_negative: bool = false;
    var read_at: usize = 0;
    var acc: usize = 0;

    if (str[0] == '-') {
        is_negative = true;
        read_at += 1;
    } else if (str[0] == '+') {
        read_at += 1;
    }

    var effective_base = base;
    if (str.len >= 3) {
        if (std.mem.eql(u8, "0x", str[0..2])) {
            effective_base = 16;
            read_at += 2;
        } else if (std.mem.eql(u8, "0d", str[0..2])) {
            effective_base = 10;
            read_at += 2;
        } else if (std.mem.eql(u8, "0b", str[0..2])) {
            effective_base = 2;
            read_at += 2;
        }
    }

    while (read_at < str.len) : (read_at += 1) {
        const ch = str[read_at];
        const digit = switch (ch) {
            '0'...'9' => ch - '0',
            'A'...'Z' => ch - 'A' + 10,
            'a'...'z' => ch - 'a' + 10,
            // TODO handle ignoring underscores in a better way
            // right now '_' in forth evaluates to 0
            '_' => continue,
            else => return error.InvalidNumber,
        };
        if (digit > effective_base) return error.InvalidNumber;
        acc = try std.math.add(usize, acc * effective_base, digit);
    }

    return if (is_negative) 0 -% acc else acc;
}

test "parse number" {
    const testing = @import("std").testing;

    try testing.expectEqual(0, try parseNumber("0", 10));
    try testing.expectEqual(100, try parseNumber("1_0_0", 10));
    try testing.expectEqual(10, try parseNumber("0d10", 36));
    try testing.expectEqual(16, try parseNumber("10", 16));
    try testing.expectEqual(16, try parseNumber("0x10", 10));
    try testing.expectEqual(8, try parseNumber("1000", 2));
    try testing.expectEqual(8, try parseNumber("0b1000", 10));
    try testing.expectEqual(-10, @as(
        isize,
        @bitCast(try parseNumber("-10", 10)),
    ));
    try testing.expectEqual(10, try parseNumber("+10", 10));
    try testing.expectEqual(845402850256, try parseNumber("asdf1234", 36));

    try testing.expectEqual(
        @as(usize, @bitCast(@as(isize, -10))),
        try parseNumber("-10", 10),
    );

    try testing.expectEqual(5, try parseNumber("11111", 1));
    try testing.expectEqual(0, try parseNumber("", 1));
}
