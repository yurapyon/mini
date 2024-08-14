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

        // TODO next line is messy
        const current_wordlist: Cell = if (state == .interpret) 0 else 1;
        var i: Cell = 0;
        while (i <= current_wordlist) : (i += 1) {
            if (try self.dictionary.find(current_wordlist - i, string)) |definition_addr| {
                return .{ .word = .{
                    .definition_addr = definition_addr,
                    .wordlist_idx = current_wordlist - i,
                } };
            }
        }

        if (try self.maybeParseNumber(string)) |value| {
            return .{
                .number = value,
            };
        }

        return null;
    }

    fn maybeParseNumber(self: *@This(), word: []const u8) !?Cell {
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
    // TODO
}
