const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
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

const externals = @import("externals.zig");
const External = externals.External;

const BufferRefiller = @import("buffer_refiller.zig").BufferRefiller;

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
    execute: [2]Cell,
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

pub const Runtime = struct {
    allocator: Allocator,
    memory: MemoryPtr,

    program_counter: Cell,
    current_token_addr: Cell,
    execute_register: Register(MainMemoryLayout.offsetOf("execute")),
    data_stack: DataStack,
    return_stack: ReturnStack,
    interpreter: Interpreter,
    input_buffer: InputBuffer,

    should_quit: bool,

    externals: ArrayList(External),

    last_evaluated_word: ?[]const u8,

    pub fn init(self: *@This(), allocator: Allocator, memory: MemoryPtr) void {
        self.allocator = allocator;
        self.memory = memory;

        self.interpreter.init(self.memory);
        self.input_buffer.init(self.memory);

        self.externals = ArrayList(External).init(allocator);

        self.last_evaluated_word = null;

        self.program_counter = 0;
        self.execute_register.init(self.memory);

        bytecodes.initBuiltins(&self.interpreter.dictionary) catch unreachable;
        self.interpreter.dictionary.updateInternalAddresses() catch unreachable;
        self.defineInternalConstants() catch unreachable;

        // TODO
        // it might work to set up the execute register so you jump to the cfa you want to call
        // rather than return have to come back just to exit
        self.execute_register.storeWithOffset(
            @sizeOf(Cell),
            self.interpreter.dictionary.tag_addresses.exit,
        ) catch unreachable;
    }

    fn defineInternalConstants(self: *@This()) !void {
        try self.defineMemoryLocationConstant("here");
        try self.defineMemoryLocationConstant("latest");
        try self.defineMemoryLocationConstant("context");
        try self.defineMemoryLocationConstant("state");
        try self.defineMemoryLocationConstant("base");
        try self.defineMemoryLocationConstant("wordlists");
        try self.interpreter.dictionary.compileConstant(
            "d0",
            MainMemoryLayout.offsetOf("dictionary_start"),
        );
        try self.interpreter.dictionary.compileConstant(
            ">in",
            MainMemoryLayout.offsetOf("input_buffer_at"),
        );
        try self.interpreter.dictionary.compileConstant(
            "true",
            cellFromBoolean(true),
        );
        try self.interpreter.dictionary.compileConstant(
            "false",
            cellFromBoolean(false),
        );
        try self.defineSourceWord();
    }

    fn defineMemoryLocationConstant(self: *@This(), comptime name: []const u8) !void {
        try self.interpreter.dictionary.compileConstant(
            name,
            MainMemoryLayout.offsetOf(name),
        );
    }

    fn defineSourceWord(self: *@This()) !void {
        const wordlist_idx = CompileState.interpret.toWordlistIndex() catch unreachable;
        try self.interpreter.dictionary.defineWord(wordlist_idx, "source");
        try self.interpreter.dictionary.here.comma(bytecodes.enter_code);
        try self.interpreter.dictionary.compileLit(MainMemoryLayout.offsetOf("input_buffer"));
        try self.interpreter.dictionary.compileLit(MainMemoryLayout.offsetOf("input_buffer_len"));
        const fetch_definition_addr = (try self.interpreter.dictionary.findWordInWordlist(wordlist_idx, "@")) orelse unreachable;
        const fetch_cfa = try self.interpreter.dictionary.toCfa(fetch_definition_addr);
        try self.interpreter.dictionary.compileXt(fetch_cfa);
        const exit_definition_addr = (try self.interpreter.dictionary.findWordInWordlist(wordlist_idx, "exit")) orelse unreachable;
        const exit_cfa = try self.interpreter.dictionary.toCfa(exit_definition_addr);
        try self.interpreter.dictionary.compileXt(exit_cfa);
    }

    pub fn defineExternal(self: *@This(), name: []const u8, wordlist_idx: Cell, id: Cell) !void {
        if (id < bytecodes.bytecodes_count) {
            return error.ReservedBytecodeId;
        }
        try self.interpreter.dictionary.defineWord(wordlist_idx, name);
        try self.interpreter.dictionary.here.comma(id);
    }

    // ===

    pub fn processBuffer(self: *@This(), file: []const u8) !void {
        var buffer: BufferRefiller = undefined;
        buffer.init(file);
        self.input_buffer.refiller = buffer.toRefiller();

        try self.interpretUntilQuit();
    }

    pub fn interpretUntilQuit(
        self: *@This(),
    ) !void {
        self.should_quit = false;

        var did_refill = try self.input_buffer.refill();

        while (did_refill and !self.should_quit) {
            const word = self.input_buffer.readNextWord();
            if (word) |w| {
                try self.evaluateString(w);
            } else {
                did_refill = try self.input_buffer.refill();
            }
        }
    }

    // ===

    pub fn evaluateString(self: *@This(), word: []const u8) !void {
        self.last_evaluated_word = word;

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

    pub fn setCfaToExecute(self: *@This(), cfa_addr: Cell) void {
        self.execute_register.store(cfa_addr);
        self.program_counter = @TypeOf(self.execute_register).offset;
    }

    fn setupExecuteLoop(self: *@This(), cfa_addr: Cell) !void {
        // NOTE
        // puts a zero on the return stack as a sentinel for the execute loop to exit
        self.return_stack.push(0);
        self.setCfaToExecute(cfa_addr);
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

            const token = try mem.readCell(self.memory, token_addr);
            if (bytecodes.getBytecode(token)) |definition| {
                try definition.callback(self);
            } else {
                try self.processExternals(token);
            }
        }
    }

    pub fn assertValidProgramCounter(self: @This()) !void {
        if (self.program_counter == 0) {
            return error.InvalidProgramCounter;
        }
    }

    pub fn advancePC(self: *@This(), offset: Cell) !void {
        try mem.assertOffsetInBounds(self.program_counter, offset);
        self.program_counter += offset;
    }

    // ===

    pub fn addExternal(self: *@This(), external: External) !void {
        try self.externals.append(external);
    }

    fn processExternals(self: *@This(), token: Cell) !void {
        if (self.externals.items.len > 0) {
            // NOTE
            // Starts at the end of the list so
            //   later externals can override earlier ones
            var i: usize = 1;
            while (i <= self.externals.items.len) : (i += 1) {
                const at = self.externals.items.len - i;
                var external = self.externals.items[at];
                if (try external.call(self, token)) {
                    return;
                }
            }
        }

        std.debug.print("Unhandled external: {}\n", .{token});
        return error.UnhandledExternal;
    }
};

test "runtime" {
    const testing = std.testing;

    const memory = try mem.allocateMemory(testing.allocator);
    defer testing.allocator.free(memory);

    var rt: Runtime = undefined;
    rt.init(memory);

    // try rt.repl();
}
