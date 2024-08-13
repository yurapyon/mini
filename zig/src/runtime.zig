const builtin = @import("builtin");

const mem = @import("memory.zig");
const MemoryPtr = mem.MemoryPtr;

const utils = @import("utils.zig");

const register = @import("register.zig");
const Register = register.Register;

const dictionary = @import("dictionary.zig");
const Dictionary = dictionary.Dictionary;

const input_buffer = @import("input_buffer.zig");
const InputBuffer = input_buffer.InputBuffer;

const interpreter = @import("interpreter.zig");
const Interpreter = interpreter.Interpreter;

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

pub const ExternalsCallback = *const fn (rt: *Runtime, userdata: ?*anyopaque) Error!void;

pub const Runtime = struct {
    memory: MemoryPtr,

    interpreter: Interpreter,

    program_counter: Cell,
    current_token_addr: Cell,
    data_stack: DataStack,
    return_stack: ReturnStack,

    externals_callback: ?ExternalsCallback,
    userdata: ?*anyopaque,

    pub fn init(self: *@This(), memory: MemoryPtr) void {
        self.memory = memory;

        self.interpreter.init(self.memory);

        self.program_counter = 0;
    }

    // ===

    pub fn executeCfa(self: *@This(), cfa_addr: Cell) Error!void {
        // NOTE
        // this puts a sentinel on the return stack
        //   with circular stacks, you can't use the depth of the return stack
        //     to signal when to exit an executionLoop
        //   so 0 is used as a sentinel, that 'exit' will pop from
        //     the return stack and store to the PC

        self.return_stack.push(0);
        self.program_counter.store(cfa_addr);
        try self.executionLoop();
    }

    pub fn advancePC(self: *@This(), offset: Cell) mem.Error!void {
        try mem.assertOffsetInBounds(self.program_counter, offset);
        self.program_counter += offset;
    }

    fn executeLoop(self: *@This()) !void {
        // Execution strategy:
        //   1. increment PC, then
        //   2. evaluate byte at PC-1
        // this makes return stack and jump logic easier
        //   because bytecodes can just set the jump location
        //     directly without having to do any math

        while (self.program_counter != 0) {
            const token_addr = try mem.readCell(self.memory, self.program_counter);
            self.current_token_addr = token_addr;

            try self.advancePC(@sizeOf(Cell));

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
    const testing = @import("std").testing;

    const memory = try mem.allocateMemory(testing.allocator);
    defer testing.allocator.free(memory);

    var rt: Runtime = undefined;
    rt.init(memory);
}
