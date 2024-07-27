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

pub const mem = @import("memory.zig");

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
    StackOverflow,
    StackUnderflow,
    ReturnStackOverflow,
    ReturnStackUnderflow,
    WordNotFound,
    WordNameTooLong,
    InvalidProgramCounter,
    InvalidAddress,
} || mem.MemoryError || InputError || SemanticsError || utils.ParseNumberError || Allocator.Error;

pub const InputError = error{
    UnexpectedEndOfInput,
    OversizeInputBuffer,
    CannotRefill,
};

pub const SemanticsError = error{
    CannotInterpret,
    CannotCompile,
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

pub const MemoryLayout = utils.MemoryLayout(struct {
    program_counter: Cell,
    data_stack_top: Cell,
    data_stack: [32]Cell,
    return_stack_top: Cell,
    return_stack: [32]Cell,
    here: Cell,
    latest: Cell,
    state: Cell,
    base: Cell,
    active_device: Cell,
    input_buffer_at: Cell,
    input_buffer_len: Cell,
    input_buffer: [128]u8,
    dictionary_start: u0,
}, Cell);

pub const BytecodeFn = *const fn (vm: *MiniVM, ctx: ExecutionContext) Error!void;

/// Passed to bytecode callbacks when they are called
pub const ExecutionContext = struct {
    current_bytecode: u8,
};

// TODO
// this should have semantics in here in a general way, and not .is_immediate
pub const WordInfo = struct {
    value: union(enum) {
        // the definition address
        mini_word: Cell,
        // the bytecode
        bytecode: u8,
        // the number
        number: Cell,
    },
    is_immediate: bool,

    fn fromMiniWord(memory: mem.CellAlignedMemory, definition_addr: Cell) Error!@This() {
        var temp_word_header: WordHeader = undefined;
        try temp_word_header.initFromMemory(memory[definition_addr..]);
        return .{
            .value = .{
                .mini_word = definition_addr,
            },
            .is_immediate = temp_word_header.is_immediate,
        };
    }

    fn fromBytecode(bytecode: u8) @This() {
        const bytecode_definition = bytecodes.getBytecodeDefinition(bytecode);
        return .{
            .value = .{
                .bytecode = bytecode,
            },
            .is_immediate = bytecode_definition.is_immediate,
        };
    }

    fn fromNumber(value: Cell) @This() {
        return .{
            .value = .{
                .number = value,
            },
            .is_immediate = false,
        };
    }
};

pub const Cell = u16;

pub fn fromBool(comptime Type: type, value: bool) Type {
    return if (value) ~@as(Type, 0) else 0;
}

pub fn isTruthy(value: anytype) bool {
    return value != 0;
}

// TODO currenly unused, should format more nicely
fn printMemoryStat(comptime name: []const u8) void {
    std.debug.print("{s}: {}\n", .{ name, MemoryLayout.offsetOf(name) });
}

// TODO currenly unused, should format more nicely
fn printMemoryStats() void {
    printMemoryStat("here");
    printMemoryStat("latest");
    printMemoryStat("state");
    printMemoryStat("base");
}

// NOTE no plans to allow for users to add aliases from mini
const AliasDefinition = struct {
    alias: []const u8,
    word: []const u8,
};

const aliases = [_]AliasDefinition{
    .{ .alias = "true", .word = "0xffff" },
    .{ .alias = "false", .word = "0" },
};

fn maybeFindAlias(word_or_alias: []const u8) ?[]const u8 {
    // TODO lookup table utils ?
    for (aliases) |alias_definition| {
        if (utils.stringsEqual(alias_definition.alias, word_or_alias)) {
            return alias_definition.word;
        }
    }
    return null;
}

/// MiniVM
/// brings together execution, stacks, dictionary, input, devices
pub const MiniVM = struct {
    memory: mem.CellAlignedMemory,

    program_counter: Register(MemoryLayout.offsetOf("program_counter")),
    data_stack: Stack(MemoryLayout.offsetOf("data_stack_top"), .{
        .start = MemoryLayout.offsetOf("data_stack"),
        .end = MemoryLayout.offsetOf("return_stack_top"),
    }),
    return_stack: Stack(MemoryLayout.offsetOf("return_stack_top"), .{
        .start = MemoryLayout.offsetOf("return_stack"),
        .end = MemoryLayout.offsetOf("here"),
    }),
    dictionary: Dictionary(
        MemoryLayout.offsetOf("here"),
        MemoryLayout.offsetOf("latest"),
    ),
    state: Register(MemoryLayout.offsetOf("state")),
    base: Register(MemoryLayout.offsetOf("base")),
    active_device: Register(MemoryLayout.offsetOf("active_device")),
    input_source: InputSource(
        MemoryLayout.offsetOf("input_buffer_at"),
        MemoryLayout.offsetOf("input_buffer_len"),
    ),
    devices: Devices,

    should_quit: bool,
    should_bye: bool,

    pub fn init(self: *@This(), memory: mem.CellAlignedMemory) !void {
        self.memory = memory;
        try self.program_counter.init(self.memory);
        try self.data_stack.initInOneMemoryBlock(self.memory);
        try self.return_stack.initInOneMemoryBlock(self.memory);
        try self.dictionary.initInOneMemoryBlock(
            self.memory,
            MemoryLayout.offsetOf("dictionary_start"),
        );
        try self.base.init(self.memory);
        try self.state.init(self.memory);
        try self.active_device.init(self.memory);
        try self.input_source.initInOneMemoryBlock(
            self.memory,
            MemoryLayout.offsetOf("input_buffer"),
        );

        self.state.store(@intFromEnum(CompileState.interpret));
        self.base.store(10);
        self.active_device.store(0);

        self.should_quit = false;
        self.should_bye = false;

        self.compileMemoryLocationConstants();

        // TODO
        // run base file
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
        self.data_stack.clear();
        // TODO
        // set refiller to cmd line input
        self.should_bye = true;
    }

    pub fn onBye(self: *@This()) Error!void {
        self.data_stack.clear();
    }

    // ===

    fn evaluateString(self: *@This(), word: []const u8) Error!void {
        if (try self.lookupString(word)) |word_info| {
            // TODO
            // this enumFromInt can crash
            //   CompileState should be non-exhaustive and throw an error if it isn't interpret or compile
            const state: CompileState = @enumFromInt(self.state.fetch());
            const effective_state = if (word_info.is_immediate) CompileState.interpret else state;
            std.debug.print("{} {s}\n", .{ effective_state, word });
            switch (effective_state) {
                .interpret => {
                    try self.interpret(word_info);
                },
                .compile => {
                    try self.compile(word_info);
                },
            }
        } else {
            // TODO printWordNotFound fn
            std.debug.print("Word not found: {s}\n", .{word});
            return error.WordNotFound;
        }
    }

    fn lookupString(self: *@This(), word_or_alias: []const u8) Error!?WordInfo {
        const word = maybeFindAlias(word_or_alias) orelse word_or_alias;
        // TODO would be nice if lookups couldnt error
        if (try self.dictionary.lookup(word)) |definition_addr| {
            return try WordInfo.fromMiniWord(self.memory, definition_addr);
        } else if (bytecodes.lookupBytecodeByName(word)) |bytecode| {
            return WordInfo.fromBytecode(bytecode);
        } else if (try self.maybeParseNumber(word)) |value| {
            return WordInfo.fromNumber(value);
        } else {
            return null;
        }
    }

    fn interpret(self: *@This(), word_info: WordInfo) Error!void {
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
    }

    fn compile(self: *@This(), word_info: WordInfo) Error!void {
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
                const cfa_addr = try WordHeader.calculateCfaAddress(self.memory, addr);
                try self.dictionary.compileAbsJump(cfa_addr);
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

    fn executeMiniWord(self: *@This(), addr: Cell) Error!void {
        const cfa_addr = try WordHeader.calculateCfaAddress(self.memory, addr);
        try self.absoluteJump(cfa_addr, true);
        try self.executionLoop();
    }

    fn executionLoop(self: *@This()) Error!void {
        // Execution strategy:
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

    pub fn absoluteJump(
        self: *@This(),
        addr: Cell,
        useReturnStack: bool,
    ) Error!void {
        if (useReturnStack) {
            self.return_stack.push(self.program_counter.fetch()) catch |err| return returnStackErrorFromStackError(err);
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
            if (value > std.math.maxInt(Cell)) {
                return null;
            }
            // NOTE
            // intCast instead of truncate
            return @intCast(value);
        } else {
            return null;
        }
    }

    // helpers for bytecodes ===

    pub fn readWordAndGetAddress(self: *@This()) Error!struct {
        is_bytecode: bool,
        value: Cell,
    } {
        const word = self.input_source.readNextWord() orelse return error.UnexpectedEndOfInput;
        if (try self.lookupString(word)) |word_info| {
            switch (word_info.value) {
                .bytecode => |bytecode| {
                    return .{
                        .is_bytecode = true,
                        .value = bytecode,
                    };
                },
                .mini_word => |addr| {
                    return .{
                        .is_bytecode = false,
                        .value = try WordHeader.calculateCfaAddress(
                            self.memory,
                            addr,
                        ),
                    };
                },
                .number => |_| {
                    std.debug.print("Word not found: {s}\n", .{word});
                    return error.WordNotFound;
                },
            }
        } else {
            std.debug.print("Word not found: {s}\n", .{word});
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
