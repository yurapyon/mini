const std = @import("std");

const FieldLayout = struct {
    name: []const u8,
    offset: usize,
};

fn fieldCount(comptime Type: type) usize {
    return std.meta.fields(Type).len;
}

fn structToMemoryLayout(comptime Type: type) [fieldCount(Type)]FieldLayout {
    switch (@typeInfo(Type)) {
        .Union, .Struct => {},
        else => {
            @compileError(std.fmt.comptimePrint(
                "Layout type '{}' must be a union or struct\n",
                .{Type},
            ));
        },
    }
    var ret = [_]FieldLayout{undefined} ** fieldCount(Type);

    var offset = 0;
    for (std.meta.fields(Type), 0..) |field, i| {
        ret[i].name = field.name;
        ret[i].offset = offset;
        offset += @sizeOf(field.type);
    }

    return ret;
}

/// Memory layouts
///   build a representation of packed memory with the ability to query offsets by field name
pub fn MemoryLayout(comptime Type: type, comptime OffsetType: type) type {
    return struct {
        pub const layout = structToMemoryLayout(Type);

        pub fn offsetOf(comptime field: []const u8) OffsetType {
            if (!@hasField(Type, field)) {
                @compileError(std.fmt.comptimePrint(
                    "Field '{s}' doesnt exist on type '{}'\n",
                    .{ field, Type },
                ));
            }
            comptime var i = 0;
            inline while (i < layout.len) : (i += 1) {
                if (std.mem.eql(u8, field, layout[i].name)) {
                    return layout[i].offset;
                }
            }
            unreachable;
        }

        pub fn memoryAt(
            comptime AccessType: type,
            memory: []u8,
            comptime field: []const u8,
        ) *AccessType {
            const offset = offsetOf(field);
            return @ptrCast(@alignCast(&memory[offset]));
        }
    };
}

test "layouts" {
    const testing = @import("std").testing;

    const TestLayout = MemoryLayout(struct {
        // 0 1 2 8 9
        a: u8,
        b: u8,
        c: [3]u16,
        d: u8,
    }, usize);

    try testing.expectEqual(TestLayout.offsetOf("a"), 0);
    try testing.expectEqual(TestLayout.offsetOf("b"), 1);
    try testing.expectEqual(TestLayout.offsetOf("c"), 2);
    try testing.expectEqual(TestLayout.offsetOf("d"), 8);

    var test_mem = [_]u8{0} ** 10;
    TestLayout.memoryAt(u8, &test_mem, "a").* = 0x01;
    TestLayout.memoryAt(u8, &test_mem, "b").* = 0x02;
    TestLayout.memoryAt([3]u16, &test_mem, "c").* = [_]u16{ 0xdead, 0xbeef, 0x1234 };
    TestLayout.memoryAt(u8, &test_mem, "d").* = 0x03;

    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 0x01, 0x02, 0xad, 0xde, 0xef, 0xbe, 0x34, 0x12, 0x03 },
        test_mem[0..9],
    );
}

pub const ParseNumberError = error{
    InvalidNumber,
    InvalidBase,
};

pub fn parseNumber(str: []const u8, base: usize) ParseNumberError!usize {
    if (base < 1 or base > 36) {
        return error.InvalidBase;
    }

    if (str.len == 0) {
        return 0;
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
            else => return error.InvalidNumber,
        };
        if (digit > effective_base) return error.InvalidNumber;
        // TODO what to do for really long numbers that will cause acc to overflow
        acc = acc * effective_base + digit;
    }

    return if (is_negative) 0 -% acc else acc;
}

test "parse number" {
    const testing = @import("std").testing;

    try testing.expectEqual(0, try parseNumber("0", 10));
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
