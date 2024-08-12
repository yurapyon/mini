const std = @import("std");

const utils = @import("utils.zig");

const mem = @import("memory.zig");
const MemoryPtr = mem.MemoryPtr;

const runtime = @import("runtime.zig");
const Cell = runtime.Cell;
const Wordlists = runtime.Wordlists;
const MainMemoryLayout = runtime.MainMemoryLayout;

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
        self.here.latest(self.memory);
        self.here.context(self.memory);
        self.here.wordlists(self.memory);

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
        if (wordlist_idx >= runtime.max_wordlists) {
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
    ) (Error || register.Error)!?Cell {
        const wordlist_latest = try self.fetchWordlistLatest(wordlist_idx);
        const iter = LinkedListIterator.from(self.memory, wordlist_latest);

        while (iter.next()) |definition_addr| {
            const name = self.getDefinitionName(definition_addr);
            if (utils.stringsEqual(to_find, name)) {
                return definition_addr;
            }
        }

        return null;
    }

    pub fn define(self: *@This(), name: []const u8) (Error || register.Error)!void {
        if (name.len > std.math.maxInt(u8)) {
            return error.WordNameTooLong;
        }

        const definition_start = self.here.alignForward();

        const context = @as(Wordlists, @enumFromInt(self.context.fetch()));
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

    fn getDefinitionName(self: @This(), definition_addr: Cell) Error![]const u8 {
        const name_info = try self.getNameLen(definition_addr);
        return mem.constSliceFromAddrAndLen(name_info.addr, name_info.len);
    }

    pub fn toCfa(self: @This(), definition_addr: Cell) Error!Cell {
        const name_info = try self.getNameLen(definition_addr);
        const name_end = name_info.addr + name_info.len;
        const definition_end = mem.alignToCell(name_end);
        return definition_end;
    }
};

test "dictionary" {
    // TODO
}
