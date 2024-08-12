const std = @import("std");

const mem = @import("memory.zig");
const MemoryPtr = mem.MemoryPtr;

const runtime = @import("runtime.zig");
const Cell = runtime.Cell;
const CompileContext = runtime.ComplieContext;
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
        self.context.store(@intFromEnum(CompileContext.forth));
        self.storeWordlistLatest(0, 0) catch unreachable;
        self.storeWordlistLatest(1, 0) catch unreachable;
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
        str: []const u8,
    ) (Error || register.Error)!void {
        const wordlist_latest = try self.fetchWordlistLatest(wordlist_idx);
        const iter = LinkedListIterator.from(self.memory, wordlist_latest);

        while (iter.next()) |addr| {
            _ = addr;
        }
        _ = str;
    }

    pub fn define(self: *@This(), name: []const u8) (Error || register.Error)!void {
        if (name.len > std.math.maxInt(u8)) {
            return error.WordNameTooLong;
        }

        const definition_start = self.here.alignForward();

        const context = @as(CompileContext, @enumFromInt(self.context.fetch()));
        const wordlist_latest = try self.fetchWordlistLatest(context);

        self.latest.store(definition_start);
        self.storeWordlistLatest(context, definition_start) catch unreachable;

        try self.here.comma(wordlist_latest);
        try self.here.commaC(@intCast(name.len));
        // TODO
        // try self.here.commaString(name);

        _ = self.here.alignForward();
    }

    pub fn toCfa(self: @This(), definition_addr: Cell) Error!Cell {
        const name_len_addr = std.math.add(Cell, definition_addr, 2) catch {
            return error.OutOfBounds;
        };
        const name_len = self.memory[name_len_addr];
        const name_end = name_len_addr + 1 + name_len;
        const definition_end = mem.alignToCell(name_end);
        return definition_end;
    }
};

test "dictionary" {
    // TODO
}
