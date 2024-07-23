const std = @import("std");

const vm = @import("MiniVM.zig");

pub const WordHeader = struct {
    // Layout:
    // |-------|---|---|---|...\0  |...|
    // ^       ^   ^           ^   ^
    // |       |   name...     |   padding to @alignOf(Cell)
    // latest  flags&name_len  terminator
    //
    // flags & name len is
    // is_immediate(1), is_hidden(1), name_len(6)

    latest: vm.Cell,
    isImmediate: bool,
    isHidden: bool,
    name: [:0]const u8,

    pub fn initFromMemory(self: *@This(), memory: []const u8) vm.Error!void {
        const latest_low = memory[0];
        const latest_high = memory[1];
        const flag_name_len = memory[2];
        self.latest = @as(u16, latest_high) << 8 | latest_low;
        self.isImmediate = (flag_name_len & 0x8) > 0;
        self.isHidden = (flag_name_len & 0x4) > 0;
        const name_len = flag_name_len & 0x3f;
        self.name = memory[3..(name_len + 3) :0];
    }

    pub fn writeToMemory(self: @This(), memory: []u8) vm.Error!void {
        memory[0] = @truncate(self.latest);
        memory[1] = @truncate(self.latest >> 8);
        if (self.isImmediate) {
            memory[2] |= 1 << 7;
        }
        if (self.isHidden) {
            memory[2] |= 1 << 6;
        }
        memory[2] |= @truncate(self.name.len & 0x3f);
        std.mem.copyForwards(u8, memory[3..], self.name);
    }

    // assumes starting address is cell aligned
    pub fn calculateLength(name_len: usize) usize {
        return std.mem.alignForward(
            usize,
            3 + name_len + 1,
            @alignOf(vm.Cell),
        );
    }
};

test "word headers" {
    const testing = @import("std").testing;

    var memory = [_]u8{0} ** 64;

    const wh_a: WordHeader = .{
        .latest = 0xbeef,
        .isImmediate = true,
        .isHidden = false,
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

    try testing.expectEqual(14, WordHeader.calculateLength(9));
    try testing.expectEqual(12, WordHeader.calculateLength(8));
}
