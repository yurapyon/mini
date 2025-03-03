const parse_number = @import("utils/parse-number.zig");
const parseNumber = parse_number.parseNumber;
const ParseNumberError = parse_number.ParseNumberError;

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
const WordInfo = dictionary.WordInfo;

const input_buffer = @import("input_buffer.zig");
const InputBuffer = input_buffer.InputBuffer;

// ===

pub const Error = error{
    InvalidCompileState,
};

pub const LookupResult = union(enum) {
    word: WordInfo,
    number: Cell,
};

pub const ParseNumberCallback =
    *const fn (str: []const u8, base: usize) ParseNumberError!usize;

pub const Interpreter = struct {
    memory: MemoryPtr,

    dictionary: Dictionary,
    state: Register(MainMemoryLayout.offsetOf("state")),
    base: Register(MainMemoryLayout.offsetOf("base")),

    parseNumberCallback: ParseNumberCallback,

    pub fn init(self: *@This(), memory: MemoryPtr) void {
        self.memory = memory;

        self.dictionary.init(self.memory);
        self.state.init(self.memory);
        self.base.init(self.memory);

        self.state.store(@intFromEnum(CompileState.interpret));
        self.base.store(10);

        self.parseNumberCallback = &parseNumber;
    }

    //

    // TODO
    //   move into dictionary?
    //   could have this ignore context.head when in compile mode
    //     ignoring the most recent definition
    pub fn lookupString(self: @This(), string: []const u8) !?LookupResult {
        const state = try CompileState.fromCell(self.state.fetch());

        const ignore_last_defined_word = state == .compile;

        if (state == .compile) {
            if (try self.dictionary.findWordInVocabulary(
                Dictionary.compiler_vocabulary_addr,
                string,
                ignore_last_defined_word,
            )) |definition_addr| {
                return .{ .word = .{
                    .definition_addr = definition_addr,
                    .context_addr = Dictionary.compiler_vocabulary_addr,
                } };
            }
        }

        const context_vocabulary_addr = self.dictionary.context.fetch();

        if (try self.dictionary.findWord(
            context_vocabulary_addr,
            string,
            ignore_last_defined_word,
        )) |word_info| {
            return .{ .word = word_info };
        }

        if (try self.maybeParseNumber(string)) |value| {
            return .{
                .number = value,
            };
        }

        return null;
    }

    // TODO move into runtime?
    fn maybeParseNumber(self: @This(), word: []const u8) !?Cell {
        const number_or_error = self.parseNumberCallback(word, self.base.fetch());
        const maybe_number = number_or_error catch |err| switch (err) {
            error.InvalidNumber => null,
            else => |e| return e,
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
    try interpreter.dictionary.define(1, "hello");

    const d1_idx = interpreter.dictionary.here.fetch();
    try interpreter.dictionary.define(0, "hello");

    const d2_idx = interpreter.dictionary.here.fetch();
    try interpreter.dictionary.define(0, "helloasdf");

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
