const std = @import("std");

const utils = @import("utils.zig");

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

const LinkedListIterator = @import("linked_list_iterator.zig").LinkedListIterator;

// ===

pub const WordInfo = struct {
    definition_addr: Cell,
    wordlist_idx: Cell,
};

pub const Dictionary = struct {
    const dictionary_start = MainMemoryLayout.offsetOf("dictionary_start");

    memory: MemoryPtr,

    here: Register(MainMemoryLayout.offsetOf("here")),
    latest: Register(MainMemoryLayout.offsetOf("latest")),
    context: Register(MainMemoryLayout.offsetOf("context")),
    wordlists: Register(MainMemoryLayout.offsetOf("wordlists")),

    tag_addresses: struct {
        lit: Cell,
        exit: Cell,
    },

    pub fn init(self: *@This(), memory: MemoryPtr) void {
        self.memory = memory;

        self.here.init(self.memory);
        self.latest.init(self.memory);
        self.context.init(self.memory);
        self.wordlists.init(self.memory);

        self.here.store(dictionary_start);
        self.latest.store(0);
        const forth_wordlist_idx = @intFromEnum(Wordlists.forth);
        const compiler_wordlist_idx = @intFromEnum(Wordlists.compiler);
        self.context.store(forth_wordlist_idx);
        self.storeWordlistLatest(forth_wordlist_idx, 0) catch unreachable;
        self.storeWordlistLatest(compiler_wordlist_idx, 0) catch unreachable;
    }

    pub fn updateInternalAddresses(self: *@This()) !void {
        const lit_definition_addr = (try self.find(0, "lit")) orelse return error.WordNotFound;
        self.tag_addresses.lit = try self.toCfa(lit_definition_addr);
        const exit_definition_addr = (try self.find(0, "exit")) orelse return error.WordNotFound;
        self.tag_addresses.exit = try self.toCfa(exit_definition_addr);
    }

    // ===

    fn assertValidWordlist(wordlist_idx: Cell) !void {
        if (wordlist_idx >= interpreter.max_wordlists) {
            return error.InvalidWordlist;
        }
    }

    fn storeWordlistLatest(
        self: *@This(),
        wordlist_idx: Cell,
        value: Cell,
    ) !void {
        try assertValidWordlist(wordlist_idx);
        const wordlist_addr = wordlist_idx * @sizeOf(Cell);
        self.wordlists.storeWithOffset(wordlist_addr, value) catch unreachable;
    }

    fn fetchWordlistLatest(self: @This(), wordlist_idx: Cell) !Cell {
        try assertValidWordlist(wordlist_idx);
        const wordlist_addr = wordlist_idx * @sizeOf(Cell);
        return self.wordlists.fetchWithOffset(wordlist_addr) catch unreachable;
    }

    // ===

    // TODO rename to findWord
    pub fn find(
        self: @This(),
        wordlist_idx: Cell,
        to_find: []const u8,
    ) !?Cell {
        const wordlist_latest = try self.fetchWordlistLatest(wordlist_idx);
        var iter = LinkedListIterator.from(self.memory, wordlist_latest);

        while (try iter.next()) |definition_addr| {
            const name = try self.getDefinitionName(definition_addr);
            if (utils.stringsEqual(to_find, name)) {
                return definition_addr;
            }
        }

        return null;
    }

    // TODO probably rename this to findWord and the above to findWordInWordlist
    pub fn search(
        self: @This(),
        starting_wordlist_idx: Cell,
        to_find: []const u8,
    ) !?WordInfo {
        var i: Cell = 0;
        while (i <= starting_wordlist_idx) : (i += 1) {
            const wordlist_idx = starting_wordlist_idx - i;
            if (try self.find(wordlist_idx, to_find)) |definition_addr| {
                return .{
                    .definition_addr = definition_addr,
                    .wordlist_idx = wordlist_idx,
                };
            }
        }

        return null;
    }

    // TODO rename to defineWord
    // TODO NOTE this checks memory bounds, so for other functions that rely on
    //   name_len being in bounds, it's technically always going to be
    //   there are ways to break this in forth though
    pub fn define(
        self: *@This(),
        wordlist_idx: Cell,
        name: []const u8,
    ) !void {
        if (name.len > std.math.maxInt(u8)) {
            return error.WordNameTooLong;
        }

        const definition_start = self.here.alignForward();

        const wordlist_latest = try self.fetchWordlistLatest(wordlist_idx);

        self.latest.store(definition_start);
        self.storeWordlistLatest(wordlist_idx, definition_start) catch unreachable;

        try self.here.comma(wordlist_latest);
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
        const wordlist_idx = CompileState.interpret.toWordlistIndex() catch unreachable;
        self.define(wordlist_idx, name) catch |err| switch (err) {
            error.InvalidWordlist => unreachable,
            else => |e| return e,
        };
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

    try dictionary.define(0, "name");

    try testing.expectEqual(
        dictionary.here.fetch() - dictionary_start,
        try dictionary.toCfa(dictionary_start) - dictionary_start,
    );

    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 0x00, 0x00, 0x04, 'n', 'a', 'm', 'e' },
        memory[dictionary_start..][0..7],
    );

    try dictionary.define(0, "hellow");

    try testing.expectEqual(dictionary_start, try dictionary.find(0, "name"));
    try testing.expectEqual(null, try dictionary.find(0, "wow"));

    const noname_addr = dictionary.here.alignForward();
    try dictionary.define(0, "");
    try testing.expectEqual(dictionary_start, try dictionary.find(0, "name"));
    try testing.expectEqual(null, try dictionary.find(0, "wow"));

    try testing.expectEqual(noname_addr, try dictionary.find(0, ""));

    // TODO more tests
}
