const std = @import("std");

const vm = @import("mini.zig");

const bytecodes = @import("bytecodes.zig");
const WordHeader = @import("word_header.zig").WordHeader;
const Register = @import("register.zig").Register;

/// This is a Forth style dictionary
///   where each definition has a pointer to the previous definition
pub fn Dictionary(
    comptime here_offset: vm.Cell,
    comptime latest_offset: vm.Cell,
) type {
    return struct {
        here: Register(here_offset),
        latest: Register(latest_offset),
        memory: vm.mem.CellAlignedMemory,

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

            self.here.alignForward(@alignOf(vm.Cell));
            const aligned_here = self.here.fetch();
            self.latest.store(aligned_here);

            try word_header.writeToMemory(try vm.mem.sliceFromAddrAndLen(
                self.memory,
                aligned_here,
                header_size,
            ));
            self.here.storeAdd(header_size);

            self.here.alignForward(@alignOf(vm.Cell));
        }

        pub fn compileLit(self: *@This(), value: vm.Cell) Register.Error!void {
            try self.here.commaC(bytecodes.lookupBytecodeByName("lit") orelse unreachable);
            try self.here.comma(value);
        }

        pub fn compileLitC(self: *@This(), value: u8) Register.Error!void {
            try self.here.commaC(bytecodes.lookupBytecodeByName("litc") orelse unreachable);
            try self.here.commaC(value);
        }

        // TODO write tests for these
        pub fn compileAbsJump(self: *@This(), addr: vm.Cell) vm.Error!void {
            if (addr > std.math.maxInt(u15)) {
                return error.InvalidAddress;
            }

            const base = @as(vm.Cell, bytecodes.base_abs_jump_bytecode) << 8;
            const jump = base | (addr & 0x7fff);
            try self.here.commaC(@truncate(jump >> 8));
            try self.here.commaC(@truncate(jump));
        }

        // TODO write tests for these
        pub fn compileData(self: *@This(), data: []u8) vm.Error!void {
            if (data.len > std.math.maxInt(u12)) {
                return error.InvalidAddress;
            }

            const base = @as(vm.Cell, bytecodes.base_data_bytecode) << 8;
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
}

test "dictionary" {
    const testing = @import("std").testing;

    const memory = try vm.mem.allocateCellAlignedMemory(
        testing.allocator,
        vm.max_memory_size,
    );
    defer testing.allocator.free(memory);

    const here_offset = 0;
    const latest_offset = 2;
    const dictionary_start = 16;

    var dictionary = Dictionary(here_offset, latest_offset){
        .here = .{ .memory = memory },
        .latest = .{ .memory = memory },
        .memory = memory,
    };

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
}
