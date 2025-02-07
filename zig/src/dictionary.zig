const std = @import("std");

const mem = @import("memory.zig");
const MemoryPtr = mem.MemoryPtr;

const runtime = @import("runtime.zig");
const Cell = runtime.Cell;
const MainMemoryLayout = runtime.MainMemoryLayout;
const CompileState = runtime.CompileState;

const bytecodes = @import("bytecodes.zig");

const interpreter = @import("interpreter.zig");
const Wordlists = interpreter.Wordlists;

const register = @import("register.zig");
const Register = register.Register;

const LinkedListIterator = @import("utils/linked_list_iterator.zig").LinkedListIterator;
const stringsEqual = @import("utils/strings-equal.zig").stringsEqual;

// ===

pub const WordInfo = struct {
    definition_addr: Cell,
    context_addr: Cell,
};

pub const Dictionary = struct {
    const dictionary_start = MainMemoryLayout.offsetOf("dictionary_start");
    pub const forth_vocabulary_addr = MainMemoryLayout.offsetOf("forth_vocabulary");
    pub const compiler_vocabulary_addr = MainMemoryLayout.offsetOf("compiler_vocabulary");

    memory: MemoryPtr,

    here: Register(MainMemoryLayout.offsetOf("here")),
    forth_vocabulary: Register(MainMemoryLayout.offsetOf("forth_vocabulary")),
    compiler_vocabulary: Register(MainMemoryLayout.offsetOf("compiler_vocabulary")),
    context: Register(MainMemoryLayout.offsetOf("context")),
    current: Register(MainMemoryLayout.offsetOf("current")),

    tag_addresses: struct {
        lit: Cell,
        exit: Cell,
    },

    pub fn init(self: *@This(), memory: MemoryPtr) void {
        self.memory = memory;

        self.here.init(self.memory);
        self.forth_vocabulary.init(self.memory);
        self.compiler_vocabulary.init(self.memory);
        self.context.init(self.memory);
        self.current.init(self.memory);

        self.here.store(dictionary_start);
        self.forth_vocabulary.store(0);
        self.compiler_vocabulary.store(0);
        self.context.store(forth_vocabulary_addr);
        self.current.store(forth_vocabulary_addr);
    }

    pub fn updateInternalAddresses(self: *@This()) !void {
        const forth_latest_addr = (try mem.cellPtr(self.memory, forth_vocabulary_addr)).*;
        const lit_definition_addr = (try self.findWordInVocabulary(forth_latest_addr, "lit")) orelse
            return error.WordNotFound;
        self.tag_addresses.lit = try self.toCfa(lit_definition_addr);
        const exit_definition_addr = (try self.findWordInVocabulary(forth_latest_addr, "exit")) orelse
            return error.WordNotFound;
        self.tag_addresses.exit = try self.toCfa(exit_definition_addr);
    }

    // ===

    pub fn getContextVocabulary(self: *@This()) !*Cell {
        const addr = self.context.fetch();
        return try mem.cellPtr(self.memory, addr);
    }

    pub fn getCurrentVocabulary(self: *@This()) *Cell {
        const addr = self.current.fetch();
        return try mem.cellPtr(self.memory, addr);
    }

    pub fn findWordInVocabulary(
        self: @This(),
        vocabulary_latest_addr: Cell,
        to_find: []const u8,
    ) !?Cell {
        var iter = LinkedListIterator.from(self.memory, vocabulary_latest_addr);

        while (try iter.next()) |definition_addr| {
            const name = try self.getDefinitionName(definition_addr);
            if (stringsEqual(to_find, name)) {
                return definition_addr;
            }
        }

        return null;
    }

    pub fn findWord(
        self: @This(),
        vocabulary_addr: Cell,
        to_find: []const u8,
    ) !?WordInfo {
        const vocabulary_latest_addr = (try mem.cellPtr(self.memory, vocabulary_addr)).*;

        if (try self.findWordInVocabulary(vocabulary_latest_addr, to_find)) |definition_addr| {
            return .{
                .definition_addr = definition_addr,
                .context_addr = vocabulary_addr,
            };
        }

        if (vocabulary_addr != forth_vocabulary_addr) {
            const forth_latest_addr = (try mem.cellPtr(self.memory, forth_vocabulary_addr)).*;
            if (try self.findWordInVocabulary(forth_latest_addr, to_find)) |definition_addr| {
                return .{
                    .definition_addr = definition_addr,
                    .context_addr = forth_vocabulary_addr,
                };
            }
        }

        return null;
    }

    // TODO NOTE this checks memory bounds, so for other functions that rely on
    //   name_len being in bounds, it's technically always going to be
    //   there are ways to break this in forth though
    pub fn defineWord(
        self: *@This(),
        vocabulary_addr: Cell,
        name: []const u8,
    ) !void {
        if (name.len > std.math.maxInt(u8)) {
            return error.WordNameTooLong;
        }

        const definition_start = self.here.alignForward();

        const current_vocabulary = try mem.cellPtr(self.memory, vocabulary_addr);
        const current_latest_addr = current_vocabulary.*;
        current_vocabulary.* = definition_start;

        try self.here.comma(current_latest_addr);
        try self.here.commaC(@intCast(name.len));
        self.here.commaString(name) catch |err| switch (err) {
            error.StringTooLong => unreachable,
            else => |e| return e,
        };

        _ = self.here.alignForward();
    }

    fn getDefinitionName(
        self: @This(),
        definition_addr: Cell,
    ) ![]const u8 {
        const name_info = try self.getNameInfo(definition_addr);
        return mem.constSliceFromAddrAndLen(self.memory, name_info.addr, name_info.len);
    }

    fn getNameInfo(
        self: @This(),
        definition_addr: Cell,
    ) !struct { addr: Cell, len: u8 } {
        try mem.assertOffsetInBounds(definition_addr, @sizeOf(Cell));
        const name_len_addr = definition_addr + @sizeOf(Cell);
        return .{
            .addr = name_len_addr + 1,
            .len = self.memory[name_len_addr],
        };
    }

    pub fn toCfa(self: @This(), definition_addr: Cell) !Cell {
        const name_info = try self.getNameInfo(definition_addr);
        const name_end = name_info.addr + name_info.len;
        const definition_end = mem.alignToCell(name_end);
        return definition_end;
    }

    // ===

    pub fn compileXt(
        self: *@This(),
        value: Cell,
    ) !void {
        try self.here.comma(value);
    }

    pub fn compileLit(
        self: *@This(),
        value: Cell,
    ) !void {
        try self.here.comma(self.tag_addresses.lit);
        try self.here.comma(value);
    }

    pub fn compileConstant(
        self: *@This(),
        name: []const u8,
        value: Cell,
    ) !void {
        const vocabulary_addr = self.current.fetch();
        try self.defineWord(vocabulary_addr, name);
        try self.here.comma(bytecodes.enter_code);
        try self.compileLit(value);
        try self.compileXt(self.tag_addresses.exit);
    }
};

test "dictionary" {
    const testing = std.testing;

    const memory = try mem.allocateMemory(testing.allocator);
    defer testing.allocator.free(memory);

    const dictionary_start = Dictionary.dictionary_start;

    var dictionary: Dictionary = undefined;
    dictionary.init(memory);

    try dictionary.defineWord(0, "name");

    try testing.expectEqual(
        dictionary.here.fetch() - dictionary_start,
        try dictionary.toCfa(dictionary_start) - dictionary_start,
    );

    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 0x00, 0x00, 0x04, 'n', 'a', 'm', 'e' },
        memory[dictionary_start..][0..7],
    );

    try dictionary.defineWord(0, "hellow");

    try testing.expectEqual(dictionary_start, try dictionary.findWordInWordlist(0, "name"));
    try testing.expectEqual(null, try dictionary.findWordInWordlist(0, "wow"));

    const noname_addr = dictionary.here.alignForward();
    try dictionary.defineWord(0, "");
    try testing.expectEqual(dictionary_start, try dictionary.findWordInWordlist(0, "name"));
    try testing.expectEqual(null, try dictionary.findWordInWordlist(0, "wow"));

    try testing.expectEqual(noname_addr, try dictionary.findWordInWordlist(0, ""));

    // TODO more tests
}
