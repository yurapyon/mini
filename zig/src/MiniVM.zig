const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const bytecodes = @import("bytecodes.zig");
const Devices = @import("devices/Devices.zig").Devices;
const Stack = @import("Stack.zig").Stack;
const WordHeader = @import("WordHeader.zig").WordHeader;
const Register = @import("Register.zig").Register;
const InputSource = @import("InputSource.zig").InputSource;
const Dictionary = @import("Dictionary.zig").Dictionary;

const utils = @import("utils.zig");

comptime {
    const native_endianness = builtin.target.cpu.arch.endian();
    if (native_endianness != .little) {
        // TODO convert u16s to little endian on memory write
        @compileError("native endianness must be .little");
    }
}

pub const max_memory_size = 64 * 1024;

pub const Error = error{
    AlignmentError,
    StackOverflow,
    StackUnderflow,
    ReturnStackOverflow,
    ReturnStackUnderflow,
    WordNotFound,
    InvalidProgramCounter,
} || InputError || utils.ParseNumberError || Allocator.Error;

pub const InputError = error{
    NoInputBuffer,
    CannotRefill,
    RefillTimeout,
};

pub fn returnStackErrorFromStackError(err: Error) Error {
    return switch (err) {
        Error.StackOverflow => Error.ReturnStackOverflow,
        Error.StackUnderflow => Error.ReturnStackUnderflow,
        else => err,
    };
}

pub const CompileState = enum(Cell) {
    interpret = 0,
    compile,
};

const DataStack = Stack(32);
const ReturnStack = Stack(32);

pub const Memory = []align(@alignOf(Cell)) u8;

pub fn allocateMemory(allocator: Allocator) Error!Memory {
    return try allocator.allocWithOptions(
        u8,
        max_memory_size,
        @alignOf(Cell),
        null,
    );
}

pub const MemoryLayout = utils.MemoryLayout(struct {
    program_counter: Cell,
    data_stack_top: Cell,
    data_stack: DataStack.MemType,
    return_stack_top: Cell,
    return_stack: ReturnStack.MemType,
    here: Cell,
    latest: Cell,
    state: Cell,
    base: Cell,
    active_device: Cell,
    dictionary_start: u0,
}, Cell);

pub const BytecodeFn = *const fn (vm: *MiniVM, ctx: ExecutionContext) Error!void;

pub const ExecutionContext = struct {
    last_bytecode: u8,
    program_counter_is_valid: bool,
};

pub const WordInfo = struct {
    value: union(enum) {
        bytecode: u8,
        mini_word: Cell,
        number: Cell,
    },
    is_immediate: bool,
};

pub const Cell = u16;

pub fn fromBool(comptime Type: type, value: bool) Type {
    return if (value) ~@as(Type, 0) else 0;
}

pub fn isTruthy(value: anytype) bool {
    return value != 0;
}

pub fn cellAt(mem: Memory, addr: Cell) *Cell {
    return @ptrCast(@alignCast(&mem[addr]));
}

/// MiniVM
/// brings together execution, stacks, dictionary, input, devices
pub const MiniVM = struct {
    memory: Memory,
    dictionary: Dictionary,
    data_stack: DataStack,
    return_stack: ReturnStack,
    input_source: InputSource,
    devices: Devices,

    program_counter: Register,
    state: Register,
    base: Register,
    active_device: Register,

    should_quit: bool,
    should_bye: bool,

    pub fn init(self: *@This(), memory: Memory) !void {
        self.memory = memory;
        self.dictionary.init(
            self.memory,
            MemoryLayout.offsetOf("latest"),
            MemoryLayout.offsetOf("here"),
        );

        self.program_counter.init(self.memory, MemoryLayout.offsetOf("program_counter"));
        self.data_stack.init(
            self.memory,
            MemoryLayout.offsetOf("data_stack_top"),
            MemoryLayout.offsetOf("data_stack"),
        );
        self.return_stack.init(
            self.memory,
            MemoryLayout.offsetOf("return_stack_top"),
            MemoryLayout.offsetOf("return_stack"),
        );
        self.state.init(self.memory, MemoryLayout.offsetOf("state"));
        self.base.init(self.memory, MemoryLayout.offsetOf("base"));
        self.active_device.init(self.memory, MemoryLayout.offsetOf("active_device"));

        self.dictionary.here.store(MemoryLayout.offsetOf("dictionary_start"));
        self.dictionary.latest.store(0);
        self.state.store(0);
        self.base.store(10);
        self.active_device.store(0);

        self.input_source.init();

        self.should_quit = false;
        self.should_bye = false;

        // TODO
        // run base file
    }

    // ===

    pub fn onQuit(self: *@This()) Error!void {
        self.data_stack.clear();
    }

    pub fn onBye(self: *@This()) Error!void {
        self.data_stack.clear();
    }

    pub fn repl(self: *@This()) Error!void {
        while (!self.should_bye) {
            self.should_quit = false;
            try self.input_source.refill();

            while (!self.should_quit and !self.should_bye) {
                const word = try self.input_source.readNextWord();
                if (word) |w| {
                    try self.interpretString(w);
                } else {
                    self.should_quit = true;
                }
            }

            try self.onQuit();
        }

        try self.onBye();
    }

    // ===

    pub fn readByteAndAdvancePC(self: *@This()) u8 {
        return self.program_counter.readByteAndAdvance(self.memory);
    }

    pub fn readCellAndAdvancePC(self: *@This()) Cell {
        return self.program_counter.readCellAndAdvance(self.memory);
    }

    pub fn absoluteJump(
        self: *@This(),
        addr: Cell,
        useReturnStack: bool,
    ) Error!void {
        if (useReturnStack) {
            try self.return_stack.push(self.program_counter.fetch());
        }
        self.program_counter.store(addr);
    }

    fn evaluateLoop(self: *@This()) Error!void {
        // Evalutation strategy:
        //   1. increment PC, then
        //   2. evaluate byte at PC-1
        // this makes return stack and jump logic easier
        //   because bytecodes can just set the jump location
        //     directly without having to do any math
        while (self.return_stack.depth() > 0) {
            const byte = self.readByteAndAdvancePC();
            try bytecodes.executeBytecode(byte, self, true);
        }
    }

    fn executeMiniWord(self: *@This(), addr: Cell) Error!void {
        // TODO limit word size somehwere

        // TODO check headersize a different way
        // const header_size = WordHeader.calculateSize(@truncate(word.len));
        const header_size = 0;
        const cfa_addr = addr + header_size;
        try self.absoluteJump(cfa_addr, false);
        try self.evaluateLoop();
    }

    // ===

    fn lookupString(self: *@This(), word: []const u8) Error!?WordInfo {
        if (bytecodes.lookupBytecodeByName(word)) |bytecode| {
            const bytecode_definition = bytecodes.getBytecodeDefinition(bytecode);
            return .{
                .value = .{
                    .bytecode = bytecode,
                },
                .is_immediate = bytecode_definition.is_immediate,
            };
        } else if (try self.dictionary.lookup(word)) |definition_addr| {
            // TODO is_immediate
            return .{
                .value = .{
                    .mini_word = definition_addr,
                },
                .is_immediate = false,
            };
            // TODO rethrow InvalidBase errors
        } else if (utils.parseNumber(word, self.base.fetch()) catch null) |value| {
            return .{
                .value = .{
                    .number = @truncate(value),
                },
                .is_immediate = false,
            };
        } else {
            return null;
        }
    }

    pub fn interpretString(self: *@This(), word: []const u8) Error!void {
        if (try self.lookupString(word)) |word_info| {
            const state: CompileState = @enumFromInt(self.state.fetch());
            const effective_state = if (word_info.is_immediate) CompileState.interpret else state;
            switch (effective_state) {
                .interpret => {
                    switch (word_info.value) {
                        .bytecode => |byte| {
                            try bytecodes.executeBytecode(byte, self, false);
                        },
                        .mini_word => |addr| {
                            try self.executeMiniWord(addr);
                        },
                        .number => |value| {
                            try self.data_stack.push(value);
                        },
                    }
                },
                .compile => {
                    self.dictionary.compile(word_info);
                },
            }
        }
    }
};

test "mini" {
    // TODO
}
