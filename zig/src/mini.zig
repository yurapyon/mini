const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const bytecodes = @import("bytecodes.zig");
const Devices = @import("devices/devices.zig").Devices;
const Stack = @import("stack.zig").Stack;
const WordHeader = @import("word_header.zig").WordHeader;
const Register = @import("register.zig").Register;
const InputSource = @import("input_source.zig").InputSource;
const Dictionary = @import("dictionary.zig").Dictionary;
const utils = @import("utils.zig");

const memory = @import("memory.zig");

pub const Error = error{
    Panic,
    AlignmentError,
    StackOverflow,
    StackUnderflow,
    ReturnStackOverflow,
    ReturnStackUnderflow,
    WordNotFound,
    WordNameTooLong,
    InvalidProgramCounter,
    InvalidAddress,
} || OutOfBoundsError || InputError || SemanticsError || utils.ParseNumberError || Allocator.Error;

pub const InputError = error{
    UnexpectedEndOfInput,
    OversizeInputBuffer,
    CannotRefill,
};

pub const SemanticsError = error{
    CannotInterpret,
    CannotCompile,
};

pub const OutOfBoundsError = error{OutOfBounds};

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

pub const max_memory_size = 64 * 1024;

const DataStack = Stack(32);
const ReturnStack = Stack(32);

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
    input_buffer: InputSource.MemType,
    input_buffer_len: Cell,
    input_buffer_at: Cell,
    dictionary_start: u0,
}, Cell);

pub const BytecodeFn = *const fn (vm: *MiniVM, ctx: ExecutionContext) Error!void;

/// Passed to bytecode callbacks when they are called
// TODO think about if we still need execution contexts
//   or if the current_bytecode and just be put in the vm instance
pub const ExecutionContext = struct {
    current_bytecode: u8,
};

// TODO this should have semantics in here and not is_immediate
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

/// MiniVM
/// brings together execution, stacks, dictionary, input, devices
pub const MiniVM = struct {
    memory: memory.CellAlignedMemory,
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

    pub fn init(self: *@This(), mem: memory.CellAlignedMemory) !void {
        self.memory = mem;
        try self.dictionary.init(
            self.memory,
            MemoryLayout.offsetOf("latest"),
            MemoryLayout.offsetOf("here"),
        );

        try self.program_counter.init(self.memory.data, MemoryLayout.offsetOf("program_counter"));
        try self.data_stack.init(
            self.memory,
            MemoryLayout.offsetOf("data_stack_top"),
            MemoryLayout.offsetOf("data_stack"),
        );
        try self.return_stack.init(
            self.memory,
            MemoryLayout.offsetOf("return_stack_top"),
            MemoryLayout.offsetOf("return_stack"),
        );
        try self.state.init(self.memory.data, MemoryLayout.offsetOf("state"));
        try self.base.init(self.memory.data, MemoryLayout.offsetOf("base"));
        try self.active_device.init(self.memory.data, MemoryLayout.offsetOf("active_device"));
        try self.input_source.init(
            self.memory,
            MemoryLayout.offsetOf("input_buffer"),
            MemoryLayout.offsetOf("input_buffer_len"),
            MemoryLayout.offsetOf("input_buffer_at"),
        );

        self.dictionary.here.store(MemoryLayout.offsetOf("dictionary_start"));
        self.dictionary.latest.store(0);
        self.state.store(0);
        self.base.store(10);
        self.active_device.store(0);

        self.should_quit = false;
        self.should_bye = false;

        self.compileMemoryLocationConstants();

        // TODO
        // run base file
    }

    // ===

    pub fn onQuit(self: *@This()) void {
        self.data_stack.clear();
    }

    pub fn onBye(self: *@This()) void {
        self.data_stack.clear();
    }

    pub fn repl(self: *@This()) Error!void {
        while (!self.should_bye) {
            self.should_quit = false;
            // TODO
            // how to handle if refiller is empty
            try self.input_source.refill();

            while (!self.should_quit and !self.should_bye) {
                const word = self.input_source.readNextWord();
                if (word) |w| {
                    try self.interpretString(w);
                } else {
                    self.should_quit = true;
                }
            }

            self.onQuit();
        }

        self.onBye();
    }

    fn compileMemoryLocationConstant(self: *@This(), comptime name: []const u8) void {
        self.dictionary.compileConstant(name, MemoryLayout.offsetOf(name)) catch unreachable;
    }

    fn compileMemoryLocationConstants(self: *@This()) void {
        self.compileMemoryLocationConstant("here");
        self.compileMemoryLocationConstant("latest");
        self.compileMemoryLocationConstant("state");
        self.compileMemoryLocationConstant("base");
    }

    // ===

    pub fn readByteAndAdvancePC(self: *@This()) OutOfBoundsError!u8 {
        return try self.program_counter.readByteAndAdvance(self.memory.data);
    }

    pub fn readCellAndAdvancePC(self: *@This()) OutOfBoundsError!Cell {
        return try self.program_counter.readCellAndAdvance(self.memory.data);
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
            const bytecode = try self.readByteAndAdvancePC();
            const ctx = ExecutionContext{
                .current_bytecode = bytecode,
            };
            try bytecodes.getBytecodeDefinition(bytecode).executeSemantics(
                self,
                ctx,
            );
        }
    }

    fn executeMiniWord(self: *@This(), addr: Cell) Error!void {
        const cfa_addr = try memory.calculateCfaAddress(self.memory, addr);
        try self.absoluteJump(cfa_addr, true);
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
        } else if (bytecodes.lookupBytecodeByName(word)) |bytecode| {
            const bytecode_definition = bytecodes.getBytecodeDefinition(bytecode);
            return .{
                .value = .{
                    .bytecode = bytecode,
                },
                .is_immediate = bytecode_definition.is_immediate,
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

    fn interpretString(self: *@This(), word: []const u8) Error!void {
        if (try self.lookupString(word)) |word_info| {
            const state: CompileState = @enumFromInt(self.state.fetch());
            const effective_state = if (word_info.is_immediate) CompileState.interpret else state;
            switch (effective_state) {
                .interpret => {
                    switch (word_info.value) {
                        .bytecode => |bytecode| {
                            const ctx = ExecutionContext{
                                .current_bytecode = bytecode,
                            };
                            try bytecodes.getBytecodeDefinition(bytecode).interpretSemantics(
                                self,
                                ctx,
                            );
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
        } else {
            std.debug.print("Word not found: {s}\n", .{word});
            return error.WordNotFound;
        }
    }

    pub fn compile(self: *@This(), word_info: WordInfo) Error!void {
        switch (word_info.value) {
            .bytecode => |bytecode| {
                const ctx = ExecutionContext{
                    .current_bytecode = bytecode,
                };
                try bytecodes.getBytecodeDefinition(bytecode).compileSemantics(
                    self,
                    ctx,
                );
            },
            .mini_word => |addr| {
                const cfa_addr = try memory.calculateCfaAddress(self.memory, addr);
                try self.dictionary.compileAbsJump(cfa_addr);
            },
            .number => |value| {
                if ((value & 0xff00) > 0) {
                    try self.dictionary.compileLit(value);
                } else {
                    try self.dictionary.compileLitC(@truncate(value));
                }
            },
        }
    }

    // helpers ===

    pub fn readWordAndGetAddress(self: *@This()) Error!struct {
        is_bytecode: bool,
        value: Cell,
    } {
        const word = self.input_source.readNextWord();
        if (word) |w| {
            const word_info = try self.lookupString(w);
            if (word_info) |wi| {
                switch (wi.value) {
                    .bytecode => |bytecode| {
                        return .{
                            .is_bytecode = true,
                            .value = bytecode,
                        };
                    },
                    .mini_word => |addr| {
                        return .{
                            .is_bytecode = false,
                            .value = try memory.calculateCfaAddress(self.memory, addr),
                        };
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
        return memory.sliceFromAddrAndLen(self.memory.data, addr, len);
    }
};

test "mini" {
    const testing = std.testing;
    const stack = @import("Stack.zig");

    var m: memory.CellAlignedMemory = undefined;
    try m.init(testing.allocator);
    defer m.deinit();

    var vm: MiniVM = undefined;
    try vm.init(m);

    try vm.input_source.setInputBuffer("1 dup 1+ dup 1+\n");

    for (0..5) |_| {
        const word = vm.input_source.readNextWord();
        if (word) |w| {
            try vm.interpretString(w);
        }
    }

    try stack.expectStack(vm.data_stack, &[_]Cell{ 1, 2, 3 });
}
