const std = @import("std");
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
const LookupResult = interpreter.LookupResult;

const stack = @import("stack.zig");
const DataStack = stack.DataStack;
const ReturnStack = stack.ReturnStack;

const bytecodes = @import("bytecodes.zig");

// ===

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

comptime {
    if (MainMemoryLayout.offsetOf("dictionary_start") >= std.math.maxInt(Cell) + 1) {
        @compileError("MainMemoryLayout doesn't fit within Memory");
    }
}

pub const CompileState = enum(Cell) {
    interpret = 0,
    compile,
    _,

    pub fn fromCell(value: Cell) !@This() {
        const state = @as(@This(), @enumFromInt(value));
        switch (state) {
            .interpret, .compile => {},
            _ => return error.InvalidCompileState,
        }
        return state;
    }

    pub fn toWordlistIndex(self: @This()) !Cell {
        return switch (self) {
            .interpret => 0,
            .compile => 1,
            _ => return error.InvalidCompileState,
        };
    }
};

pub const ExternalError = error{
    ExternalPanic,
};

pub const ExternalsCallback = *const fn (rt: *Runtime, userdata: ?*anyopaque) ExternalError!void;

pub const Runtime = struct {
    memory: MemoryPtr,

    program_counter: Cell,
    current_token_addr: Cell,
    data_stack: DataStack,
    return_stack: ReturnStack,
    interpreter: Interpreter,
    input_buffer: InputBuffer,

    should_bye: bool,
    should_quit: bool,

    externals_callback: ?ExternalsCallback,
    userdata: ?*anyopaque,

    pub fn init(self: *@This(), memory: MemoryPtr) void {
        self.memory = memory;

        self.interpreter.init(self.memory);
        self.input_buffer.init(self.memory);

        self.program_counter = 0;
    }

    // ===

    pub fn repl(self: *@This()) !void {
        self.should_bye = false;

        while (!self.should_bye) {
            self.should_quit = false;

            var did_refill = try self.input_buffer.refill();

            while (did_refill and !self.should_quit and !self.should_bye) {
                const word = self.input_buffer.readNextWord();
                if (word) |w| {
                    try self.evaluateString(w);
                } else {
                    did_refill = try self.input_buffer.refill();
                }
            }

            try self.onQuit();
        }

        try self.onBye();
    }

    pub fn onQuit(self: *@This()) !void {
        // TODO set refiller to cmd line input
        // TODO remove next line when bye/quit logic is figured out
        self.should_bye = true;
    }

    pub fn onBye(self: *@This()) !void {
        _ = self;
    }

    // ===

    pub fn evaluateString(self: *@This(), word: []const u8) !void {
        const state = try CompileState.fromCell(self.interpreter.state.fetch());

        if (try self.interpreter.lookupString(word)) |lookup_result| {
            switch (state) {
                .interpret => {
                    try self.interpret(lookup_result);
                },
                .compile => {
                    try self.compile(lookup_result);
                },
                _ => unreachable,
            }
        } else {
            // TODO printWordNotFound fn
            // std.debug.print("Word not found: {s}\n", .{word});
            return error.WordNotFound;
        }
    }

    fn interpret(self: *@This(), lookup_result: LookupResult) !void {
        switch (lookup_result) {
            .word => |word| {
                const cfa_addr = try self.interpreter.dictionary.toCfa(word.definition_addr);
                try self.setupExecuteLoop(cfa_addr);
                try self.executeLoop();
            },
            .number => |value| {
                self.data_stack.push(value);
            },
        }
    }

    fn compile(self: *@This(), lookup_result: LookupResult) !void {
        switch (lookup_result) {
            .word => |word| {
                const cfa_addr = try self.interpreter.dictionary.toCfa(word.definition_addr);

                const compiler_wordlist = try CompileState.compile.toWordlistIndex();
                if (word.wordlist_idx == compiler_wordlist) {
                    try self.setupExecuteLoop(cfa_addr);
                    try self.executeLoop();
                } else {
                    try self.interpreter.dictionary.compileXt(cfa_addr);
                }
            },
            .number => |value| {
                try self.interpreter.dictionary.compileLit(value);
            },
        }
    }

    fn setupExecuteLoop(self: *@This(), cfa_addr: Cell) !void {
        // NOTE
        // this sets program_counter to 0 so a call to 'enter' can push 0 to the return stack

        self.program_counter = 0;
        self.current_token_addr = cfa_addr;
        try self.executeCfaAddr(cfa_addr);
    }

    // Assumes self.program_counter is on the cell to execute
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
            try self.executeCfaAddr(token_addr);
        }
    }

    fn executeCfaAddr(self: *@This(), cfa_addr: Cell) !void {
        const token = try mem.readCell(self.memory, cfa_addr);
        if (bytecodes.getBytecode(token)) |definition| {
            try definition.callback(self);
        } else {
            // TODO call external fn
            unreachable;
        }
    }

    pub fn assertValidProgramCounter(self: @This()) error{InvalidProgramCounter}!void {
        if (self.program_counter == 0) {
            return error.InvalidProgramCounter;
        }
    }

    pub fn advancePC(self: *@This(), offset: Cell) error{OutOfBounds}!void {
        try mem.assertOffsetInBounds(self.program_counter, offset);
        self.program_counter += offset;
    }
};

test "runtime" {
    const testing = @import("std").testing;

    const memory = try mem.allocateMemory(testing.allocator);
    defer testing.allocator.free(memory);

    var rt: Runtime = undefined;
    rt.init(memory);

    try rt.repl();
}
