const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const bytecodes = @import("bytecodes.zig");
const Devices = @import("devices/Devices.zig").Devices;
const Stack = @import("Stack.zig").Stack;
const WordHeader = @import("WordHeader.zig").WordHeader;
const Register = @import("Register.zig").Register;

const utils = @import("utils.zig");

comptime {
    const nativeEndianness = builtin.target.cpu.arch.endian();
    if (nativeEndianness != .little) {
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
} || utils.ParseNumberError || Allocator.Error;

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

pub const BytecodeFn = *const fn (vm: *MiniVM) Error!void;

const WordLookupResult = union(enum) {
    bytecode: u8,
    mini_word: Cell,
    number: Cell,
    not_found,
};

pub const Cell = u16;

pub fn fromBool(comptime Type: type, value: bool) Type {
    return if (value) ~@as(Type, 0) else 0;
}

pub fn isTruthy(value: anytype) bool {
    return value != 0;
}

pub fn isWhitespace(char: u8) bool {
    return char == ' ' or char == '\n';
}

pub fn cellAt(mem: Memory, addr: Cell) *Cell {
    return @ptrCast(@alignCast(&mem[addr]));
}

pub const MiniVM = struct {
    memory: Memory,

    program_counter: Register,
    data_stack: DataStack,
    return_stack: ReturnStack,
    here: Register,
    latest: Register,
    state: Register,
    base: Register,
    active_device: Register,

    // TODO move this into a device ? somehow
    input_buffer: []const u8,
    input_buffer_at: usize,

    should_quit: bool,
    should_bye: bool,

    devices: Devices,

    pub fn init(self: *@This(), memory: Memory) !void {
        self.memory = memory;

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
        self.here.init(self.memory, MemoryLayout.offsetOf("here"));
        self.latest.init(self.memory, MemoryLayout.offsetOf("latest"));
        self.state.init(self.memory, MemoryLayout.offsetOf("state"));
        self.base.init(self.memory, MemoryLayout.offsetOf("base"));
        self.active_device.init(self.memory, MemoryLayout.offsetOf("active_device"));

        self.here.store(MemoryLayout.offsetOf("dictionary_start"));
        self.latest.store(0);
        self.state.store(0);
        self.base.store(10);
        self.active_device.store(0);

        self.should_quit = false;
        self.should_bye = false;

        // TODO
        // run base file
    }

    pub fn deinit(self: @This()) void {
        _ = self;
    }

    // ===

    pub fn onQuit(self: *@This()) Error!void {
        self.data_stack.clear();
    }

    pub fn onBye(self: *@This()) Error!void {
        self.data_stack.clear();
    }

    // ===

    pub fn setInputBuffer(self: *@This(), buffer: []const u8) void {
        self.input_buffer = buffer;
        self.input_buffer_at = 0;
    }

    pub fn readNextChar(self: *@This()) ?u8 {
        if (self.input_buffer_at + 1 < self.input_buffer.len) {
            self.input_buffer_at += 1;
            return self.input_buffer[self.input_buffer_at];
        } else {
            return null;
        }
    }

    pub fn readNextWord(self: *@This()) ?[]const u8 {
        var char = self.input_buffer[self.input_buffer_at];

        while (isWhitespace(char)) {
            char = self.readNextChar() orelse return null;
        }

        const word_start = self.input_buffer_at;

        while (!isWhitespace(char)) {
            char = self.readNextChar() orelse break;
        }

        return self.input_buffer[word_start..self.input_buffer_at];
    }

    fn lookupMiniDefinition(self: *@This(), word: []const u8) Error!?Cell {
        var latest = self.latest.fetch();
        var temp_word_header: WordHeader = undefined;
        while (latest != 0) : (latest = temp_word_header.latest) {
            try temp_word_header.initFromMemory(self.memory[latest..]);
            if (temp_word_header.nameEquals(word)) {
                return latest;
            }
        }
        return null;
    }

    fn lookupWord(self: *@This(), word: []const u8) Error!WordLookupResult {
        if (bytecodes.getCallbackBytecode(word)) |bytecode| {
            return .{ .bytecode = bytecode };
        } else if (try self.lookupMiniDefinition(word)) |definition_addr| {
            return .{ .mini_word = definition_addr };
            // TODO rethrow InvalidBase errors
        } else if (utils.parseNumber(word, self.base.fetch()) catch null) |value| {
            return .{ .number = @truncate(value) };
        } else {
            return WordLookupResult.not_found;
        }
    }

    fn interpretWord(self: *@This(), word: []const u8) Error!void {
        switch (try self.lookupWord(word)) {
            .bytecode => |byte| {
                try self.evaluateByte(byte, false);
            },
            .mini_word => |addr| {
                // TODO limit word size somewhere
                const header_size = WordHeader.calculateSize(@truncate(word.len));
                const cfa_addr = addr + header_size;
                try self.absoluteJump(cfa_addr, false);
                try self.evaluateLoop();
            },
            .number => |value| {
                try self.data_stack.push(value);
            },
            .not_found => return Error.WordNotFound,
        }
    }

    fn compileWord(self: *@This(), word: []const u8) Error!void {
        // TODO
        switch (try self.lookupWord(word)) {
            .bytecode => |byte| {
                // if is immediate
                _ = byte;
            },
            .mini_word => |addr| {
                // if is immediate
                _ = addr;
                // try self.evaluateLoop();
            },
            .number => |value| {
                _ = value;
            },
            .not_found => return Error.WordNotFound,
        }
    }

    pub fn interpretLoop(self: *@This()) Error!void {
        while (!self.should_quit and !self.should_bye) {
            const word = self.readNextWord();
            if (word) |w| {
                const state: CompileState = @enumFromInt(self.state.fetch());
                switch (state) {
                    .interpret => {
                        try self.interpretWord(w);
                    },
                    .compile => {
                        try self.compileWord(w);
                    },
                }
            } else {
                self.should_quit = true;
            }
        }

        try self.onQuit();
    }

    // example main loop
    pub fn repl(self: *@This()) Error!void {
        while (!self.should_bye) {
            self.should_quit = false;
            // TODO
            // refill input buffer
            try self.interpretLoop();
        }

        try self.onBye();
    }

    pub fn readByteAndAdvancePC(self: *@This()) u8 {
        const pc_at = self.program_counter.fetch();
        // TODO handle reaching end of memory
        self.program_counter.storeAdd(1);
        return self.memory[pc_at];
    }

    pub fn readCellAndAdvancePC(self: *@This()) Cell {
        const low = self.readByteAndAdvancePC();
        const high = self.readByteAndAdvancePC();
        return @as(Cell, high) << 8 | low;
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

    // NOTE
    // evalutation strategy
    //   1. increment pc, then
    //   2. evaluate byte at pc-1
    // this makes return stack and jump logic easier

    fn evaluateLoop(self: *@This()) Error!void {
        while (self.return_stack.depth() > 0) {
            const byte = self.readByteAndAdvancePC();
            try self.evaluateByte(byte, true);
        }
    }

    // program_counter may be moved
    fn evaluateByte(self: *@This(), byte: u8, programCounterIsValid: bool) Error!void {
        switch (byte) {
            inline 0b00000000...0b01101111 => |b| {
                const id = b & 0x7f;
                const named_callback = bytecodes.getCallbackById(id);
                if (programCounterIsValid or !named_callback.needsValidProgramCounter) {
                    try named_callback.callback(self);
                } else {
                    return Error.InvalidProgramCounter;
                }
            },
            inline 0b01110000...0b01111111 => |b| {
                if (!programCounterIsValid) {
                    return Error.InvalidProgramCounter;
                }
                // TODO how should endianness be handled for this
                const high = b & 0x0f;
                const low = self.readByteAndAdvancePC();
                const addr = self.program_counter.fetch();
                const length = @as(Cell, high) << 8 | low;
                try self.data_stack.push(addr);
                try self.data_stack.push(length);
                self.program_counter.storeAdd(length);
            },
            inline 0b10000000...0b11111111 => |b| {
                if (!programCounterIsValid) {
                    return Error.InvalidProgramCounter;
                }
                // TODO how should endianness be handled for this
                const high = b & 0x7f;
                const low = self.readByteAndAdvancePC();
                const addr = @as(Cell, high) << 8 | low;
                try self.absoluteJump(addr, true);
            },
        }
    }

    fn alignHere(self: *@This()) void {
        self.here.store(std.mem.alignForward(
            Cell,
            self.here.fetch(),
            @alignOf(Cell),
        ));
    }

    pub fn defineWordHeader(
        self: *@This(),
        name: []const u8,
    ) Error!void {
        const word_header = WordHeader{
            .latest = self.latest.fetch(),
            .isImmediate = false,
            .isHidden = false,
            .name = name,
        };
        const header_size = @as(Cell, @truncate(word_header.size()));
        self.alignHere();
        self.latest.store(self.here.fetch());
        try word_header.writeToMemory(
            self.memory[self.here.fetch()..][0..header_size],
        );
        self.here.storeAdd(header_size);
        self.alignHere();
    }
};
