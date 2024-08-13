const std = @import("std");

const utils = @import("utils.zig");

const mem = @import("memory.zig");
const MemoryPtr = mem.MemoryPtr;

const runtime = @import("runtime.zig");
const Cell = runtime.Cell;
const MainMemoryLayout = runtime.MainMemoryLayout;

const interpreter = @import("interpreter.zig");
const Wordlists = interpreter.Wordlists;

const register = @import("register.zig");
const Register = register.Register;

const LinkedListIterator = @import("linked_list_iterator.zig").LinkedListIterator;

pub const Error = error{
    OutOfBounds,
    InvalidWordlist,
    WordNameTooLong,
};

pub const Dictionary = struct {
    const dictionary_start = MainMemoryLayout.offsetOf("dictionary_start");

    memory: MemoryPtr,

    here: Register(MainMemoryLayout.offsetOf("here")),
    latest: Register(MainMemoryLayout.offsetOf("latest")),
    context: Register(MainMemoryLayout.offsetOf("context")),
    wordlists: Register(MainMemoryLayout.offsetOf("wordlists")),

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

    // ===

    fn assertValidWordlist(wordlist_idx: Cell) Error!void {
        if (wordlist_idx >= interpreter.max_wordlists) {
            return error.InvalidWordlist;
        }
    }

    fn storeWordlistLatest(
        self: *@This(),
        wordlist_idx: Cell,
        value: Cell,
    ) Error!void {
        try assertValidWordlist(wordlist_idx);
        const wordlist_addr = wordlist_idx * @sizeOf(Cell);
        self.wordlists.storeWithOffset(wordlist_addr, value) catch unreachable;
    }

    fn fetchWordlistLatest(self: @This(), wordlist_idx: Cell) Error!Cell {
        try assertValidWordlist(wordlist_idx);
        const wordlist_addr = wordlist_idx * @sizeOf(Cell);
        return self.wordlists.fetchWithOffset(wordlist_addr) catch unreachable;
    }

    // ===

    pub fn find(
        self: @This(),
        wordlist_idx: Cell,
        to_find: []const u8,
    ) (Error || register.Error || mem.Error)!?Cell {
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

    pub fn define(
        self: *@This(),
        name: []const u8,
    ) (Error || register.Error || mem.Error)!void {
        if (name.len > std.math.maxInt(u8)) {
            return error.WordNameTooLong;
        }

        const definition_start = self.here.alignForward();

        const context = self.context.fetch();
        const wordlist_latest = try self.fetchWordlistLatest(context);

        self.latest.store(definition_start);
        self.storeWordlistLatest(context, definition_start) catch unreachable;

        try self.here.comma(wordlist_latest);
        try self.here.commaC(@intCast(name.len));
        try self.here.commaString(name);

        _ = self.here.alignForward();
    }

    fn getNameInfo(self: @This(), definition_addr: Cell) Error!struct { addr: Cell, len: u8 } {
        const name_len_addr = std.math.add(Cell, definition_addr, 2) catch {
            return error.OutOfBounds;
        };
        return .{
            .addr = name_len_addr + 1,
            .len = self.memory[name_len_addr],
        };
    }

    fn getDefinitionName(
        self: @This(),
        definition_addr: Cell,
    ) (Error || mem.Error)![]const u8 {
        const name_info = try self.getNameInfo(definition_addr);
        return mem.constSliceFromAddrAndLen(self.memory, name_info.addr, name_info.len);
    }

    pub fn toCfa(self: @This(), definition_addr: Cell) Error!Cell {
        const name_info = try self.getNameInfo(definition_addr);
        const name_end = name_info.addr + name_info.len;
        const definition_end = mem.alignToCell(name_end);
        return definition_end;
    }

    // ===

    pub fn compileLit(self: *@This(), value: Cell) Error!void {
        _ = self;
        _ = value;
        // TODO
    }
};

test "dictionary" {
    const testing = @import("std").testing;

    const memory = try mem.allocateMemory(testing.allocator);
    defer testing.allocator.free(memory);

    const dictionary_start = Dictionary.dictionary_start;

    var dictionary: Dictionary = undefined;
    dictionary.init(memory);

    try dictionary.define("name");

    try testing.expectEqual(
        dictionary.here.fetch() - dictionary_start,
        try dictionary.toCfa(dictionary_start) - dictionary_start,
    );

    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 0x00, 0x00, 0x04, 'n', 'a', 'm', 'e' },
        memory[dictionary_start..][0..7],
    );

    try dictionary.define("hellow");

    try testing.expectEqual(dictionary_start, try dictionary.find(0, "name"));
    try testing.expectEqual(null, try dictionary.find(0, "wow"));

    const noname_addr = dictionary.here.alignForward();
    try dictionary.define("");
    try testing.expectEqual(dictionary_start, try dictionary.find(0, "name"));
    try testing.expectEqual(null, try dictionary.find(0, "wow"));

    try testing.expectEqual(noname_addr, try dictionary.find(0, ""));

    // TODO more tests
}
