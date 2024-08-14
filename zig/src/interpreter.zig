const utils = @import("utils.zig");

const mem = @import("memory.zig");
const MemoryPtr = mem.MemoryPtr;

const runtime = @import("runtime.zig");
const Cell = runtime.Cell;
const CompileState = runtime.CompileState;
const MainMemoryLayout = runtime.MainMemoryLayout;

const register = @import("register.zig");
const Register = register.Register;

const dictionary = @import("dictionary.zig");
const Dictionary = dictionary.Dictionary;

const input_buffer = @import("input_buffer.zig");
const InputBuffer = input_buffer.InputBuffer;

// ===

pub const Error = error{
    InvalidCompileState,
};

pub const LookupResult = union(enum) {
    word: struct {
        definition_addr: Cell,
        wordlist_idx: Cell,
    },
    number: Cell,
};

pub const Wordlists = enum(Cell) {
    forth = 0,
    compiler,
    _,
};

pub const max_wordlists = 2;

pub const Interpreter = struct {
    memory: MemoryPtr,

    dictionary: Dictionary,
    state: Register(MainMemoryLayout.offsetOf("state")),
    base: Register(MainMemoryLayout.offsetOf("base")),

    pub fn init(self: *@This(), memory: MemoryPtr) void {
        self.memory = memory;

        self.dictionary.init(self.memory);
        self.state.init(self.memory);
        self.base.init(self.memory);

        self.state.store(@intFromEnum(CompileState.interpret));
        self.base.store(10);
    }

    //

    pub fn lookupString(self: @This(), string: []const u8) !?LookupResult {
        const state = try CompileState.fromCell(self.state.fetch());
        const current_wordlist = try state.toWordlistIndex();
        var i: Cell = 0;
        while (i <= current_wordlist) : (i += 1) {
            const wordlist_idx = current_wordlist - i;
            if (try self.dictionary.find(wordlist_idx, string)) |definition_addr| {
                return .{
                    .word = .{
                        .definition_addr = definition_addr,
                        .wordlist_idx = current_wordlist - i,
                    },
                };
            }
        }

        if (try self.maybeParseNumber(string)) |value| {
            return .{
                .number = value,
            };
        }

        return null;
    }

    fn maybeParseNumber(self: @This(), word: []const u8) !?Cell {
        const number_or_error = utils.parseNumber(word, self.base.fetch());
        const maybe_number = number_or_error catch |err| switch (err) {
            error.InvalidNumber => null,
            else => return err,
        };
        if (maybe_number) |value| {
            // NOTE
            // We are truncating here
            //   if a number is too big it will just get wrapped % 2^16
            return @truncate(value);
        } else {
            return null;
        }
    }
};

test "interpreter" {
    const testing = @import("std").testing;

    const memory = try mem.allocateMemory(testing.allocator);
    defer testing.allocator.free(memory);

    var interpreter: Interpreter = undefined;
    interpreter.init(memory);

    const d0_idx = interpreter.dictionary.here.fetch();
    interpreter.dictionary.context.store(1);
    try interpreter.dictionary.define("hello");

    const d1_idx = interpreter.dictionary.here.fetch();
    interpreter.dictionary.context.store(0);
    try interpreter.dictionary.define("hello");

    const d2_idx = interpreter.dictionary.here.fetch();
    interpreter.dictionary.context.store(0);
    try interpreter.dictionary.define("helloasdf");

    interpreter.state.store(1);
    try testing.expectEqual(
        LookupResult{
            .word = .{
                .definition_addr = d0_idx,
                .wordlist_idx = 1,
            },
        },
        try interpreter.lookupString("hello"),
    );

    try testing.expectEqual(
        LookupResult{
            .word = .{
                .definition_addr = d2_idx,
                .wordlist_idx = 0,
            },
        },
        try interpreter.lookupString("helloasdf"),
    );

    interpreter.state.store(0);
    try testing.expectEqual(
        LookupResult{
            .word = .{
                .definition_addr = d1_idx,
                .wordlist_idx = 0,
            },
        },
        try interpreter.lookupString("hello"),
    );

    interpreter.base.store(10);
    try testing.expectEqual(
        LookupResult{
            .number = 1234,
        },
        try interpreter.lookupString("1234"),
    );

    try testing.expectEqual(
        LookupResult{
            .number = 0xbeef,
        },
        try interpreter.lookupString("0xbeef"),
    );

    interpreter.base.store(16);
    try testing.expectEqual(
        LookupResult{
            .number = 0xbeef,
        },
        try interpreter.lookupString("beef"),
    );
}
