const std = @import("std");

const vm = @import("MiniVM.zig");

const bytecodes = @import("bytecodes.zig");
const WordHeader = @import("WordHeader.zig").WordHeader;
const Register = @import("Register.zig").Register;

pub const Dictionary = struct {
    // TODO i think this should be a pointer ?
    memory: vm.Memory,
    here: Register,
    latest: Register,

    // Note
    // assumes latest and here are in the same memory block as the dictionary
    pub fn init(
        self: *@This(),
        memory: vm.Memory,
        here_offset: vm.Cell,
        latest_offset: vm.Cell,
    ) void {
        self.memory = memory;
        self.here.init(memory, here_offset);
        self.latest.init(memory, latest_offset);
    }

    pub fn lookup(
        self: *@This(),
        word: []const u8,
    ) vm.Error!?vm.Cell {
        var latest = self.latest.fetch();
        var temp_word_header: WordHeader = undefined;
        while (latest != 0) : (latest = temp_word_header.latest) {
            try temp_word_header.initFromMemory(self.memory[latest..]);
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

        try word_header.writeToMemory(
            self.memory[aligned_here..][0..header_size],
        );
        self.here.storeAdd(header_size);

        self.here.alignForward(vm.Cell);
    }

    pub fn compileLit(self: *@This(), value: vm.Cell) void {
        self.here.comma(bytecodes.lookupBytecodeByName("lit") orelse unreachable);
        self.here.comma(value);
    }

    pub fn compileLitC(self: *@This(), value: u8) void {
        self.here.comma(bytecodes.lookupBytecodeByName("litc") orelse unreachable);
        self.here.commaC(value);
    }

    pub fn compile(self: *@This(), word_info: vm.WordInfo) void {
        switch (word_info.value) {
            .bytecode => |bytecode| {
                switch (bytecodes.determineType(bytecode)) {
                    .basic => {
                        self.here.commaC(bytecode);
                    },
                    .data, .absolute_jump => {
                        // TODO error
                        // this is a case that shouldnt happen in normal execution
                        // but may happen if compile was called not from the main executor
                    },
                }
            },
            .mini_word => |addr| {
                _ = addr;
                // TODO
                // compile an abs jump to the cfa of this addr
            },
            .number => |value| {
                if ((value & 0xff00) > 0) {
                    self.compileLit(value);
                } else {
                    self.compileLitC(@truncate(value));
                }
            },
        }
    }
};

test "dictionary" {
    const testing = @import("std").testing;

    const memory = try vm.allocateMemory(testing.allocator);
    defer testing.allocator.free(memory);

    const here_offset = 0;
    const latest_offset = 2;
    const dictionary_start = 16;

    var dictionary: Dictionary = undefined;
    dictionary.init(memory, here_offset, latest_offset);

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
        memory[dictionary_start..][0..8],
    );

    const wh_a: WordHeader = .{
        .latest = 0,
        .is_immediate = false,
        .is_hidden = false,
        .name = "name",
    };

    var wh_b: WordHeader = undefined;

    try wh_b.initFromMemory(memory[dictionary_start..]);
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
        memory[dictionary.latest.fetch()..][0..8],
    );

    try wh_b.initFromMemory(memory[dictionary.latest.fetch()..]);
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

    // TODO test dictionary.compile
}
