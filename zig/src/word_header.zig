const std = @import("std");

const vm = @import("mini.zig");
const utils = @import("utils.zig");

/// Struct representing a MiniVM word definition
///   this is not bit-for-bit equivalent to the definition in Forth memory
///   this is just a normal Zig struct
pub const WordHeader = struct {
    latest: vm.Cell,
    is_immediate: bool,
    is_hidden: bool,
    name: []const u8,

    pub fn initFromMemory(self: *@This(), memory: []const u8) vm.mem.MemoryError!void {
        if (memory.len < self.size()) {
            return error.OutOfBounds;
        }

        const latest_low = memory[0];
        const latest_high = memory[1];
        const flag_name_len = memory[2];
        self.latest = @as(u16, latest_high) << 8 | latest_low;
        self.is_immediate = (flag_name_len & 0x80) > 0;
        self.is_hidden = (flag_name_len & 0x40) > 0;
        const name_len = flag_name_len & 0x3f;
        self.name = memory[3..(name_len + 3)];
    }

    pub fn writeToMemory(self: @This(), memory: []u8) vm.Error!void {
        if (self.name.len > std.math.maxInt(u6)) {
            return error.WordNameTooLong;
        }

        if (memory.len < self.size()) {
            return error.OutOfBounds;
        }

        memory[0] = @truncate(self.latest);
        memory[1] = @truncate(self.latest >> 8);
        var flag_name_len = @as(u8, @truncate(self.name.len & 0x3f));
        if (self.is_immediate) {
            flag_name_len |= 1 << 7;
        }
        if (self.is_hidden) {
            flag_name_len |= 1 << 6;
        }
        memory[2] = flag_name_len;
        std.mem.copyForwards(u8, memory[3..], self.name);
        memory[self.name.len + 3] = 0;
    }

    pub fn nameEquals(self: @This(), name: []const u8) bool {
        return utils.stringsEqual(self.name, name);
    }

    // assumes starting address is cell aligned
    pub fn calculateSize(name_len: u6) u8 {
        return std.mem.alignForward(
            u8,
            3 + name_len + 1,
            @alignOf(vm.Cell),
        );
    }

    pub fn size(self: @This()) u8 {
        return calculateSize(@truncate(self.name.len));
    }

    pub fn calculateCfaAddress(memory: []u8, base_addr: vm.Cell) vm.Error!vm.Cell {
        try vm.mem.assertMemoryAccess(memory, base_addr);
        var temp_word_header: WordHeader = undefined;
        try temp_word_header.initFromMemory(memory[base_addr..]);
        return base_addr + temp_word_header.size();
    }
};

test "word headers" {
    const testing = @import("std").testing;

    var memory = [_]u8{0} ** 64;

    const wh_a: WordHeader = .{
        .latest = 0xbeef,
        .is_immediate = true,
        .is_hidden = false,
        .name = "mini-word",
    };

    try wh_a.writeToMemory(&memory);

    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 0xef, 0xbe, 0x89, 'm', 'i', 'n', 'i', '-', 'w', 'o', 'r', 'd', 0 },
        memory[0..13],
    );

    var wh_b: WordHeader = undefined;
    try wh_b.initFromMemory(&memory);

    try testing.expectEqualDeep(wh_b, wh_a);

    try testing.expectEqual(14, WordHeader.calculateSize(9));
    try testing.expectEqual(12, WordHeader.calculateSize(8));

    try testing.expect(wh_a.nameEquals("mini-word"));

    const wh_c: WordHeader = .{
        .latest = 0,
        .is_immediate = false,
        .is_hidden = false,
        .name = "name",
    };

    try wh_c.writeToMemory(&memory);

    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 0x00, 0x00, 0x04, 'n', 'a', 'm', 'e', 0 },
        memory[0..8],
    );
}
