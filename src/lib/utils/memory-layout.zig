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
        .@"union", .@"struct" => {},
        else => {
            @compileError(std.fmt.comptimePrint(
                "Layout type '{}' must be a union or struct\n",
                .{Type},
            ));
        },
    }

    const fields = std.meta.fields(Type);

    var ret = [_]FieldLayout{undefined} ** fieldCount(Type);

    var offset = 0;

    var breakpoint: struct {
        found: bool,
        index: usize,
    } = undefined;
    breakpoint.found = false;

    for (fields, 0..) |field, i| {
        if (std.mem.eql(u8, field.name, "_")) {
            breakpoint.found = true;
            breakpoint.index = i;
            break;
        } else {
            ret[i].name = field.name;
            ret[i].offset = offset;
            offset += @sizeOf(field.type);
        }
    }

    if (breakpoint.found) {
        var i: usize = fields.len;
        offset = 65536;

        while (i > 0) : (i -= 1) {
            const field = fields[i - 1];
            offset -= @sizeOf(field.type);
            ret[i - 1].name = field.name;
            ret[i - 1].offset = offset;
            if (i - 1 == breakpoint.index) break;
        }
    }

    return ret;
}

/// Memory layouts
///   build a representation of packed memory with the ability to query offsets by field name
pub fn MemoryLayout(comptime Type: type) type {
    return struct {
        pub const layout = structToMemoryLayout(Type);

        pub fn offsetOf(comptime field: []const u8) comptime_int {
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
    });

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
