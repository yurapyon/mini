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
    Panic,
    AlignmentError,
    StackOverflow,
    StackUnderflow,
    ReturnStackOverflow,
    ReturnStackUnderflow,
    WordNotFound,
    WordNameTooLong,
    CannotInterpretWord,
    InvalidProgramCounter,
    CannotGetAddressOfBytecode,
} || InputError || utils.ParseNumberError || Allocator.Error;

pub const InputError = error{
    UnexpectedEndOfInput,
    NoInputBuffer,
    CannotRefill,
};

pub fn returnStackErrorFromStackError(err: Error) Error {
    return switch (err) {
        error.StackOverflow => error.ReturnStackOverflow,
        error.StackUnderflow => error.ReturnStackUnderflow,
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

pub fn sliceFromAddrAndLen(memory: []u8, addr: usize, len: usize) []u8 {
    // TODO handle out of bounds errors
    return memory[addr..][0..len];
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

/// Passed to bytecode callbacks when they are called
pub const ExecutionContext = struct {
    current_bytecode: u8,
    program_counter_is_valid: bool,
};

// TODO this is a little messy
pub const WordInfo = struct {
    value: union(enum) {
        // the bytecode
        bytecode: u8,
        // the definition address
        mini_word: Cell,
        // the number
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

pub fn calculateCfaAddress(memory: Memory, addr: Cell) Error!Cell {
    var temp_word_header: WordHeader = undefined;
    try temp_word_header.initFromMemory(memory[addr..]);
    return addr + temp_word_header.size();
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
            const bytecode = self.readByteAndAdvancePC();
            const ctx = ExecutionContext{
                .current_bytecode = bytecode,
                .program_counter_is_valid = true,
            };
            try bytecodes.getBytecodeDefinition(bytecode).executeSemantics(
                self,
                ctx,
            );
        }
    }

    fn executeMiniWord(self: *@This(), addr: Cell) Error!void {
        const cfa_addr = try calculateCfaAddress(self.memory, addr);
        try self.absoluteJump(cfa_addr, false);
        try self.evaluateLoop();
    }

    fn executeBytecode(
        self: *@This(),
        bytecode: u8,
        ctx: ExecutionContext,
    ) Error!void {
        try bytecodes.getBytecodeDefinition(bytecode).callback(self, ctx);
    }

    // ===

    fn lookupString(self: *@This(), word: []const u8) Error!?WordInfo {
        if (try self.dictionary.lookup(word)) |definition_addr| {
            var temp_word_header: WordHeader = undefined;
            try temp_word_header.initFromMemory(self.memory[definition_addr..]);
            return .{
                .value = .{
                    .mini_word = definition_addr,
                },
                .is_immediate = temp_word_header.is_immediate,
            };
            // TODO rethrow InvalidBase errors
        } else if (bytecodes.lookupBytecodeByName(word)) |bytecode| {
            const bytecode_definition = bytecodes.getBytecodeDefinition(bytecode);
            return .{
                .value = .{
                    .bytecode = bytecode,
                },
                .is_immediate = bytecode_definition.is_immediate,
            };
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

    fn interpretString(self: *@This(), word: []const u8) Error!void {
        if (try self.lookupString(word)) |word_info| {
            const state: CompileState = @enumFromInt(self.state.fetch());
            const effective_state = if (word_info.is_immediate) CompileState.interpret else state;
            switch (effective_state) {
                .interpret => {
                    switch (word_info.value) {
                        .bytecode => |bytecode| {
                            switch (bytecodes.BytecodeType.fromBytecode(bytecode)) {
                                .basic => {
                                    const ctx = ExecutionContext{
                                        .current_bytecode = bytecode,
                                        .program_counter_is_valid = false,
                                    };
                                    try bytecodes.getBytecodeDefinition(bytecode).interpretSemantics(
                                        self,
                                        ctx,
                                    );
                                },
                                .data, .absolute_jump => return error.CannotInterpretWord,
                            }
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
                    try self.compile(word_info);
                },
            }
        }
    }

    pub fn compile(self: *@This(), word_info: WordInfo) Error!void {
        switch (word_info.value) {
            .bytecode => |bytecode| {
                const ctx = ExecutionContext{
                    .current_bytecode = bytecode,
                    // TODO what is this?
                    .program_counter_is_valid = false,
                };
                try bytecodes.getBytecodeDefinition(bytecode).compileSemantics(
                    self,
                    ctx,
                );
            },
            .mini_word => |addr| {
                const cfa_addr = try calculateCfaAddress(self.memory, addr);
                self.dictionary.compileAbsJump(cfa_addr);
            },
            .number => |value| {
                if ((value & 0xff00) > 0) {
                    self.dictionary.compileLit(value);
                } else {
                    self.dictionary.compileLitC(@truncate(value));
                }
            },
        }
    }

    // helpers ===

    pub fn readWordAndGetCfaAddress(self: *@This()) Error!Cell {
        const word = try self.input_source.readNextWord();
        if (word) |w| {
            const word_info = try self.lookupString(w);
            if (word_info) |wi| {
                switch (wi.value) {
                    .bytecode => |_| {
                        return error.CannotGetAddressOfBytecode;
                    },
                    .mini_word => |addr| {
                        return calculateCfaAddress(self.memory, addr);
                    },
                    .number => |_| {
                        return error.WordNotFound;
                    },
                }
            } else {
                return error.WordNotFound;
            }
        } else {
            return error.UnexpectedEndOfInput;
        }
    }

    pub fn popSlice(self: *@This()) Error![]u8 {
        const len, const addr = try self.data_stack.popMultiple(2);
        return sliceFromAddrAndLen(self.memory, addr, len);
    }
};

test "mini" {
    // TODO
}
