const std = @import("std");

const vm = @import("mini.zig");
const memory = @import("memory.zig");

const bytecodes = @import("bytecodes.zig");
const WordHeader = @import("word_header.zig").WordHeader;
const Register = @import("register.zig").Register;

/// This is a Forth style dictionary
///   where each definition has a pointer to the previous definition
pub const Dictionary = struct {
    // TODO should this be a *vm.Memory pointer?
    _memory: memory.CellAlignedMemory,
    here: Register,
    latest: Register,

    // NOTE
    // Assumes latest and here are in the same memory block as the dictionary
    pub fn init(
        self: *@This(),
        mem: memory.CellAlignedMemory,
        here_offset: vm.Cell,
        latest_offset: vm.Cell,
    ) Register.Error!void {
        self._memory = mem;
        try self.here.init(self._memory, here_offset);
        try self.latest.init(self._memory, latest_offset);
    }

    pub fn lookup(
        self: *@This(),
        word: []const u8,
    ) vm.Error!?vm.Cell {
        var latest = self.latest.fetch();
        var temp_word_header: WordHeader = undefined;
        while (latest != 0) : (latest = temp_word_header.latest) {
            try temp_word_header.initFromMemory(self._memory.data[latest..]);
            if (!temp_word_header.is_hidden and temp_word_header.nameEquals(word)) {
                return latest;
            }
        }
        return null;
    }

    pub fn defineWord(
        self: *@This(),
        name: []const u8,
    ) vm.Error!void {
        const word_header = WordHeader{
            .latest = self.latest.fetch(),
            .is_immediate = false,
            .is_hidden = false,
            .name = name,
        };

        const header_size = word_header.size();

        self.here.alignForward(vm.Cell);
        const aligned_here = self.here.fetch();
        self.latest.store(aligned_here);

        try word_header.writeToMemory(try memory.sliceFromAddrAndLen(
            self._memory.data,
            aligned_here,
            header_size,
        ));
        self.here.storeAdd(header_size);

        self.here.alignForward(vm.Cell);
    }

    pub fn compileLit(self: *@This(), value: vm.Cell) Register.Error!void {
        try self.here.commaC(bytecodes.lookupBytecodeByName("lit") orelse unreachable);
        try self.here.comma(value);
    }

    pub fn compileLitC(self: *@This(), value: u8) Register.Error!void {
        try self.here.commaC(bytecodes.lookupBytecodeByName("litc") orelse unreachable);
        try self.here.commaC(value);
    }

    pub fn compileAbsJump(self: *@This(), addr: vm.Cell) vm.Error!void {
        if (addr > std.math.maxInt(u15)) {
            return error.InvalidAddress;
        }

        const base = bytecodes.base_abs_jump_bytecode;
        const jump = base | (addr & 0x7fff);
        try self.here.commaC(@truncate(jump >> 8));
        try self.here.commaC(@truncate(jump));
    }

    pub fn compileData(self: *@This(), data: []u8) vm.Error!void {
        if (data.len > std.math.maxInt(u12)) {
            return error.InvalidAddress;
        }

        const base = bytecodes.base_data_bytecode;
        const data_len = base | @as(vm.Cell, @truncate(data.len & 0x0fff));
        try self.here.commaC(@truncate(data_len >> 8));
        try self.here.commaC(@truncate(data_len));
        for (data) |byte| {
            try self.here.commaC(byte);
        }
    }

    pub fn compileConstant(
        self: *@This(),
        name: []const u8,
        value: vm.Cell,
    ) vm.Error!void {
        try self.defineWord(name);
        try self.compileLit(value);
        try self.here.commaC(bytecodes.lookupBytecodeByName("exit") orelse unreachable);
    }
};

test "dictionary" {
    const testing = @import("std").testing;

    var m: memory.CellAlignedMemory = undefined;
    try m.init(testing.allocator);
    defer m.deinit();

    const here_offset = 0;
    const latest_offset = 2;
    const dictionary_start = 16;

    var dictionary: Dictionary = undefined;
    try dictionary.init(m, here_offset, latest_offset);

    dictionary.here.store(dictionary_start);
    dictionary.latest.store(0);

    try dictionary.defineWord("name");

    try testing.expectEqual(
        dictionary.here.fetch() - dictionary_start,
        WordHeader.calculateSize(4),
    );

    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 0x00, 0x00, 0x04, 'n', 'a', 'm', 'e', 0 },
        m.data[dictionary_start..][0..8],
    );

    const wh_a: WordHeader = .{
        .latest = 0,
        .is_immediate = false,
        .is_hidden = false,
        .name = "name",
    };

    var wh_b: WordHeader = undefined;

    try wh_b.initFromMemory(m.data[dictionary_start..]);
    try testing.expectEqualDeep(wh_a, wh_b);

    const c_latest = dictionary.latest.fetch();

    const wh_c: WordHeader = .{
        .latest = c_latest,
        .is_immediate = false,
        .is_hidden = false,
        .name = "wowo",
    };

    try dictionary.defineWord("wowo");

    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 0x10, 0x00, 0x04, 'w', 'o', 'w', 'o', 0 },
        m.data[dictionary.latest.fetch()..][0..8],
    );

    try wh_b.initFromMemory(m.data[dictionary.latest.fetch()..]);
    try testing.expectEqualDeep(wh_c, wh_b);

    try dictionary.defineWord("hellow");

    try testing.expectEqual(dictionary_start, try dictionary.lookup("name"));
    try testing.expectEqual(
        dictionary_start + WordHeader.calculateSize(4),
        try dictionary.lookup("wowo"),
    );
    try testing.expectEqual(
        null,
        try dictionary.lookup("wow"),
    );
    try testing.expectEqual(
        dictionary_start + (WordHeader.calculateSize(4) * 2),
        try dictionary.lookup("hellow"),
    );
}
