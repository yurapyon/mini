const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const bytecodes = @import("bytecodes.zig");
const Stack = @import("stack.zig").Stack;
const Register = @import("register.zig").Register;
const InputSource = @import("input_source.zig").InputSource;
const dictionary = @import("dictionary.zig");
const Dictionary = @import("dictionary.zig").Dictionary;
const utils = @import("utils.zig");
// TODO rename somehow
const t = @import("terminator.zig");
const external = @import("ext_bytecodes.zig");

pub const mem = @import("memory.zig");

comptime {
    const native_endianness = builtin.target.cpu.arch.endian();
    if (native_endianness != .little) {
        // TODO convert u16s to little endian on memory write
        @compileError("native endianness must be .little");
    }
}

const VMCallbacks = struct {
    // return a boolean saying whether VM should
    //   continue with its default behavior after calling the callback
    const CallbackFn = *const fn (mini: *MiniVM, userdata: ?*anyopaque) Error!bool;

    userdata: ?*anyopaque = null,
    onQuit: CallbackFn = nop,
    onBye: CallbackFn = nop,
    // TODO these potentially could take an ExecutionContext
    // which is to say maybe that could just be stored as part of the vm
    onExecuteLoop: CallbackFn = nop,
    onExecuteBytecode: CallbackFn = nop,
    onExit: CallbackFn = nop,

    fn nop(_: *MiniVM, _: ?*anyopaque) Error!bool {
        return true;
    }
};

// TODO
// make an error, error.NumberOverflow instead of just using the builtin error.Overflow

pub const max_memory_size = 64 * 1024;

pub const Error = error{
    Panic,
    StackOverflow,
    StackUnderflow,
    ReturnStackOverflow,
    ReturnStackUnderflow,
    InvalidProgramCounter,
    InvalidAddress,
    InvalidCompileState,
} || mem.MemoryError || WordError || InputError || SemanticsError || utils.ParseNumberError || MathError || Allocator.Error;

pub const InputError = error{
    UnexpectedEndOfInput,
    OversizeInputBuffer,
    CannotRefill,
};

pub const SemanticsError = error{
    CannotInterpret,
    CannotCompile,
};

pub const WordError = error{
    WordNotFound,
    WordNameTooLong,
    WordNameInvalid,
};

pub const MathError = error{ Overflow, DivisionByZero, NegativeDenominator };

// TODO this isnt working right
pub fn returnStackErrorFromStackError(err: Error) Error {
    return switch (err) {
        error.StackOverflow => error.ReturnStackOverflow,
        error.StackUnderflow => error.ReturnStackUnderflow,
        else => err,
    };
}

// TODO could rename this to interpreter state
pub const CompileState = enum(Cell) {
    interpret = 0,
    compile,
    _,
};

pub const CompileContext = enum(Cell) {
    forth = 0,
    compiler,
    _,
};

pub const MemoryLayout = utils.MemoryLayout(struct {
    program_counter: Cell,
    return_stack_top: Cell,
    return_stack: [32]Cell,
    return_stack_end: u0,
    data_stack_top: Cell,
    data_stack: [32]Cell,
    data_stack_end: u0,
    here: Cell,
    latest: Cell,
    context: Cell,
    wordlists: [2]Cell,
    state: Cell,
    base: Cell,
    input_buffer_at: Cell,
    input_buffer_len: Cell,
    input_buffer: [128]u8,
    dictionary_start: u0,
}, Cell);

pub const BytecodeFn = *const fn (vm: *MiniVM, ctx: ExecutionContext) Error!void;

pub const ExternalFn = *const fn (vm: *MiniVM, ctx: ExecutionContext, userdata: ?*anyopaque) Error!void;

/// Passed to bytecode callbacks when they are called
pub const ExecutionContext = struct {
    current_bytecode: u8,
};

pub const WordInfo = union(enum) {
    // TODO have to come up with a uniform name to refer to 'mini word's
    mini_word: struct {
        definition_addr: Cell,
        is_immediate: bool,
    },
    bytecode: u8,
    number: Cell,

    // TODO rename to 'is compiler word' or something
    fn fromMiniWord(definition_addr: Cell, is_immediate: bool) Error!@This() {
        return .{
            .mini_word = .{
                .definition_addr = definition_addr,
                .is_immediate = is_immediate,
            },
        };
    }

    fn fromBytecode(bytecode: u8) @This() {
        return .{ .bytecode = bytecode };
    }

    fn fromNumber(value: Cell) @This() {
        return .{ .number = value };
    }
};

pub const Cell = u16;
pub const SignedCell = i16;

pub fn fromBool(comptime Type: type, value: bool) Type {
    return if (value) ~@as(Type, 0) else 0;
}

pub fn isTruthy(value: anytype) bool {
    return value != 0;
}

/// MiniVM
/// brings together execution, stacks, dictionary, input
pub const MiniVM = struct {
    memory: mem.CellAlignedMemory,

    program_counter: Register(MemoryLayout.offsetOf("program_counter")),
    return_stack: Stack(MemoryLayout.offsetOf("return_stack_top"), .{
        .start = MemoryLayout.offsetOf("return_stack"),
        .end = MemoryLayout.offsetOf("return_stack_end"),
    }),
    data_stack: Stack(MemoryLayout.offsetOf("data_stack_top"), .{
        .start = MemoryLayout.offsetOf("data_stack"),
        .end = MemoryLayout.offsetOf("data_stack_end"),
    }),
    dictionary: Dictionary(
        MemoryLayout.offsetOf("here"),
        MemoryLayout.offsetOf("latest"),
        MemoryLayout.offsetOf("context"),
        MemoryLayout.offsetOf("wordlists"),
    ),
    state: Register(MemoryLayout.offsetOf("state")),
    base: Register(MemoryLayout.offsetOf("base")),
    input_source: InputSource(
        MemoryLayout.offsetOf("input_buffer_at"),
        MemoryLayout.offsetOf("input_buffer_len"),
    ),

    should_quit: bool,
    should_bye: bool,

    callbacks: VMCallbacks,

    pub fn init(self: *@This(), memory: mem.CellAlignedMemory, callbacks: VMCallbacks) !void {
        self.memory = memory;

        const panic_byte = bytecodes.lookupBytecodeByName("panic") orelse unreachable;
        for (self.memory) |*byte| {
            byte.* = panic_byte;
        }

        try self.program_counter.init(self.memory);
        try self.return_stack.initInOneMemoryBlock(self.memory);
        try self.data_stack.initInOneMemoryBlock(self.memory);
        try self.dictionary.initInOneMemoryBlock(
            self.memory,
            MemoryLayout.offsetOf("dictionary_start"),
        );
        try self.state.init(self.memory);
        try self.base.init(self.memory);
        try self.input_source.initInOneMemoryBlock(
            self.memory,
            MemoryLayout.offsetOf("input_buffer"),
        );

        self.state.store(@intFromEnum(CompileState.interpret));
        self.base.store(10);

        self.should_quit = false;
        self.should_bye = false;

        self.callbacks = callbacks;

        self.compileMemoryLocationConstants();
        try external.defineAll(self);

        // TODO
        // run base file ?
        // probably not
    }

    fn compileMemoryLocationConstant(self: *@This(), comptime name: []const u8) void {
        self.dictionary.compileConstant(name, MemoryLayout.offsetOf(name)) catch unreachable;
    }

    fn compileMemoryLocationConstants(self: *@This()) void {
        self.compileMemoryLocationConstant("here");
        self.compileMemoryLocationConstant("latest");
        self.compileMemoryLocationConstant("context");
        self.compileMemoryLocationConstant("state");
        self.compileMemoryLocationConstant("base");
        self.dictionary.compileConstant(
            "r0",
            MemoryLayout.offsetOf("return_stack"),
        ) catch unreachable;
        self.dictionary.compileConstant(
            "d0",
            MemoryLayout.offsetOf("dictionary_start"),
        ) catch unreachable;
        self.dictionary.compileConstant(
            ">in",
            MemoryLayout.offsetOf("input_buffer_at"),
        ) catch unreachable;
        self.compileSourceWord();
    }

    fn compileSourceWord(self: *@This()) void {
        self.dictionary.defineWord("source") catch unreachable;
        self.dictionary.compileLit(MemoryLayout.offsetOf("input_buffer")) catch unreachable;
        self.dictionary.compileLit(MemoryLayout.offsetOf("input_buffer_len")) catch unreachable;
        const fetch_bytecode = bytecodes.lookupBytecodeByName("@") orelse unreachable;
        self.dictionary.here.commaC(self.dictionary.memory, fetch_bytecode) catch unreachable;
        const exit_bytecode = bytecodes.lookupBytecodeByName("exit") orelse unreachable;
        self.dictionary.here.commaC(self.dictionary.memory, exit_bytecode) catch unreachable;
    }

    // ===

    pub fn repl(self: *@This()) Error!void {
        while (!self.should_bye) {
            self.should_quit = false;

            var did_refill = try self.input_source.refill();

            while (did_refill and !self.should_quit and !self.should_bye) {
                const word = self.input_source.readNextWord();
                if (word) |w| {
                    try self.evaluateString(w);
                } else {
                    did_refill = try self.input_source.refill();
                }
            }

            try self.onQuit();
        }

        try self.onBye();
    }

    pub fn onQuit(self: *@This()) Error!void {
        const should_continue = try self.callbacks.onQuit(self, self.callbacks.userdata);
        if (should_continue) {
            self.data_stack.clear();
            // TODO
            // set refiller to cmd line input
            // TODO remove next line when bye/quit logic is figured out
            self.should_bye = true;
        }
    }

    pub fn onBye(self: *@This()) Error!void {
        const should_continue = try self.callbacks.onBye(self, self.callbacks.userdata);
        if (should_continue) {
            self.data_stack.clear();
        }
    }

    // ===

    fn evaluateString(self: *@This(), word: []const u8) Error!void {
        const state = @as(CompileState, @enumFromInt(self.state.fetch()));
        const wordlist_idx: Cell = if (state == .interpret) 0 else 1;
        if (try self.lookupString(wordlist_idx, word)) |word_info| {
            switch (state) {
                .interpret => {
                    try self.interpret(word_info);
                },
                .compile => {
                    try self.compile(word_info);
                },
                else => return error.InvalidCompileState,
            }
        } else {
            // TODO printWordNotFound fn
            std.debug.print("Word not found: {s}\n", .{word});
            return error.WordNotFound;
        }
    }

    fn lookupString(self: *@This(), wordlist_idx: Cell, str: []const u8) Error!?WordInfo {
        // TODO would be nice if lookups couldnt error
        if (try self.dictionary.lookup(wordlist_idx, str)) |lookup_result| {
            const is_immediate = lookup_result.wordlist_idx == 1;
            return try WordInfo.fromMiniWord(lookup_result.addr, is_immediate);
        } else if (bytecodes.lookupBytecodeByName(str)) |bytecode| {
            return WordInfo.fromBytecode(bytecode);
        } else if (try self.maybeParseNumber(str)) |value| {
            return WordInfo.fromNumber(value);
        } else {
            return null;
        }
    }

    fn interpret(self: *@This(), word_info: WordInfo) Error!void {
        switch (word_info) {
            .bytecode => |bytecode| {
                const ctx = ExecutionContext{
                    .current_bytecode = bytecode,
                };
                try bytecodes.getBytecodeDefinition(bytecode).interpretSemantics(
                    self,
                    ctx,
                );
            },
            .mini_word => |mini_word| {
                const cfa_addr = try self.dictionary.toCfa(mini_word.definition_addr);
                try self.executeCfa(cfa_addr);
            },
            .number => |value| {
                try self.data_stack.push(value);
            },
        }
    }

    fn compile(self: *@This(), word_info: WordInfo) Error!void {
        switch (word_info) {
            .bytecode => |bytecode| {
                const ctx = ExecutionContext{
                    .current_bytecode = bytecode,
                };
                try bytecodes.getBytecodeDefinition(bytecode).compileSemantics(
                    self,
                    ctx,
                );
            },
            .mini_word => |mini_word| {
                const cfa_addr = try self.dictionary.toCfa(mini_word.definition_addr);
                if (mini_word.is_immediate) {
                    try self.executeCfa(cfa_addr);
                } else {
                    try self.dictionary.compileAbsJump(cfa_addr);
                }
            },
            .number => |value| {
                if (value > std.math.maxInt(u8)) {
                    try self.dictionary.compileLit(value);
                } else {
                    try self.dictionary.compileLitC(@truncate(value));
                }
            },
        }
    }

    pub fn executeCfa(self: *@This(), cfa_addr: Cell) Error!void {
        // NOTE
        // this puts some 'dummy data' on the return stack
        // the 'dummy data' is actually the xt currently being executed
        //   and can be accessed with `r0 @` from forth
        // i think its more clear to write it out this way
        //   rather than using the absoluteJump function below
        self.return_stack.push(cfa_addr) catch |err| {
            return returnStackErrorFromStackError(err);
        };
        self.program_counter.store(cfa_addr);
        try self.executionLoop();
    }

    pub fn executionLoop(self: *@This()) Error!void {
        // Execution strategy:
        //   1. increment PC, then
        //   2. evaluate byte at PC-1
        // this makes return stack and jump logic easier
        //   because bytecodes can just set the jump location
        //     directly without having to do any math

        // TODO should we care about this return?
        _ = try self.callbacks.onExecuteLoop(self, self.callbacks.userdata);

        while (self.return_stack.depth() > 0) {
            const should_continue = try self.callbacks.onExecuteBytecode(self, self.callbacks.userdata);
            if (should_continue) {
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
    }

    pub fn absoluteJump(
        self: *@This(),
        addr: Cell,
        useReturnStack: bool,
    ) Error!void {
        if (useReturnStack) {
            self.return_stack.push(self.program_counter.fetch()) catch |err| {
                return returnStackErrorFromStackError(err);
            };
        }
        self.program_counter.store(addr);
    }

    pub fn readByteAndAdvancePC(self: *@This()) mem.MemoryError!u8 {
        return try self.program_counter.readByteAndAdvance(self.memory);
    }

    pub fn readCellAndAdvancePC(self: *@This()) mem.MemoryError!Cell {
        return try self.program_counter.readCellAndAdvance(self.memory);
    }

    // ===

    fn maybeParseNumber(self: *@This(), word: []const u8) Error!?Cell {
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

    // helpers for bytecodes ===

    pub fn lookupStringAndGetAddress(self: *@This(), str: []const u8) Error!struct {
        is_bytecode: bool,
        value: Cell,
    } {
        // NOTE TODO
        // in this case lookupString could have a early return to not try and parse numbers
        if (try self.lookupString(1, str)) |word_info| {
            switch (word_info) {
                .bytecode => |bytecode| {
                    return .{
                        .is_bytecode = true,
                        .value = bytecode,
                    };
                },
                .mini_word => |mini_word| {
                    return .{
                        .is_bytecode = false,
                        .value = mini_word.definition_addr,
                    };
                },
                .number => |_| {
                    return error.WordNotFound;
                },
            }
        } else {
            return error.WordNotFound;
        }
    }

    /// pops ( addr len -- ) from the stack and return as a []u8
    pub fn popSlice(self: *@This()) Error![]u8 {
        const len, const addr = try self.data_stack.popMultiple(2);
        return mem.sliceFromAddrAndLen(self.memory, addr, len);
    }
};

test "mini" {
    // TODO
    // write more tests for execution and interpreting
    //   this code could maybe be more testable in general
    const testing = std.testing;
    const stack = @import("Stack.zig");

    const memory = try mem.allocateCellAlignedMemory(
        testing.allocator,
        max_memory_size,
    );
    defer testing.allocator.free(memory);

    var vm: MiniVM = undefined;
    try vm.init(memory);

    try vm.input_source.setInputBuffer("1 dup 1+ dup 1+\n");

    for (0..5) |_| {
        const word = vm.input_source.readNextWord();
        if (word) |w| {
            try vm.evaluateString(w);
        }
    }

    try stack.expectStack(vm.data_stack, &[_]Cell{ 1, 2, 3 });
}
