const builtin = @import("builtin");

const mem = @import("memory.zig");
const MemoryPtr = mem.MemoryPtr;

const utils = @import("utils.zig");

const dictionary = @import("dictionary.zig");
const Dictionary = dictionary.Dictionary;

const register = @import("register.zig");
const Register = register.Register;

const stack = @import("stack.zig");
const DataStack = stack.DataStack;
const ReturnStack = stack.ReturnStack;

const bytecodes = @import("bytecodes.zig");

comptime {
    const native_endianness = builtin.target.cpu.arch.endian();
    if (native_endianness != .little) {
        @compileError("native endianness must be .little");
    }
}

pub const Cell = u16;

pub fn cellFromBoolean(value: bool) Cell {
    return if (value) 0xffff else 0;
}

pub fn isTruthy(value: Cell) bool {
    return value != 0;
}

pub const Error = error{
    ExternalPanic,
} || mem.Error;

pub const MainMemoryLayout = utils.MemoryLayout(struct {
    here: Cell,
    latest: Cell,
    context: Cell,
    wordlists: [2]Cell,
    state: Cell,
    base: Cell,
    input_buffer: [128]u8,
    input_buffer_at: Cell,
    input_buffer_len: Cell,
    dictionary_start: u0,
});

pub const max_wordlists = 2;

pub const Wordlists = enum(Cell) {
    forth = 0,
    compiler,
    _,
};

pub const ExternalsCallback = *const fn (rt: *Runtime, userdata: ?*anyopaque) Error!void;

pub const Runtime = struct {
    memory: MemoryPtr,
    program_counter: Cell,
    current_token_addr: Cell,
    data_stack: DataStack,
    return_stack: ReturnStack,
    dictionary: Dictionary,
    state: Register(MainMemoryLayout.offsetOf("state")),
    base: Register(MainMemoryLayout.offsetOf("base")),

    userdata: ?*anyopaque,
    externals_callback: ?ExternalsCallback,

    pub fn init(self: *@This(), memory: MemoryPtr) void {
        self.memory = memory;
        self.program_counter = 0;
        self.dictionary.init(memory);
        self.state.init(memory);
        self.base.init(memory);
    }

    // ===

    fn defineBuiltin(
        name: []const u8,
    ) void {
        // TODO
        _ = name;
    }

    // ===

    fn executeLoop(self: *@This()) !void {
        while (self.return_stack.peek() != 0) {
            const token_addr = try mem.readCell(self.memory, self.program_counter);
            self.current_token_addr = token_addr;
            const token = try mem.readCell(self.memory, token_addr);
            if (bytecodes.getBytecode(token)) |definition| {
                try definition.callback(self);
            } else {
                // TODO call external fn
                unreachable;
            }
        }
    }
};

test "runtime" {
    const r: Runtime = undefined;
    _ = r;
}
