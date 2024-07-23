const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const bytecodes = @import("bytecodes.zig");
const Devices = @import("devices/Devices.zig").Devices;
const Stack = @import("Stack.zig").Stack;
const WordHeader = @import("WordHeader.zig").WordHeader;
const Register = @import("Register.zig").Register;
const InputSource = @import("InputSource.zig").InputSource;

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

pub const BytecodeFn = *const fn (vm: *MiniVM) Error!void;

// todo could put isImmediate in here too
const WordInfo = union(enum) {
    bytecode: u8,
    mini_word: Cell,
    number: Cell,
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

    input_source: InputSource,

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

        self.input_source.init();

        self.should_quit = false;
        self.should_bye = false;

        // TODO
        // run base file
    }

    pub fn deinit(self: @This()) void {
        _ = self;
        // note: currently does nothing
    }

    // ===

    pub fn onQuit(self: *@This()) Error!void {
        self.data_stack.clear();
    }

    pub fn onBye(self: *@This()) Error!void {
        self.data_stack.clear();
    }

    // ===

    fn lookupMiniDefinition(self: *@This(), word: []const u8) Error!?Cell {
        // TODO account for isHidden
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

    fn lookupWord(self: *@This(), word: []const u8) Error!?WordInfo {
        if (bytecodes.getCallbackBytecode(word)) |bytecode| {
            return .{ .bytecode = bytecode };
        } else if (try self.lookupMiniDefinition(word)) |definition_addr| {
            return .{ .mini_word = definition_addr };
            // TODO rethrow InvalidBase errors
        } else if (utils.parseNumber(word, self.base.fetch()) catch null) |value| {
            return .{ .number = @truncate(value) };
        } else {
            return null;
        }
    }

    fn interpretWord(self: *@This(), wordInfo: WordInfo) Error!void {
        switch (wordInfo) {
            .bytecode => |byte| {
                try self.evaluateByte(byte, false);
            },
            .mini_word => |addr| {
                // TODO limit word size somewhere
                // TODO check headersize a different way
                // const header_size = WordHeader.calculateSize(@truncate(word.len));
                const header_size = 0;
                const cfa_addr = addr + header_size;
                try self.absoluteJump(cfa_addr, false);
                try self.evaluateLoop();
            },
            .number => |value| {
                try self.data_stack.push(value);
            },
        }
    }

    fn compileWord(self: *@This(), wordInfo: WordInfo) Error!void {
        switch (wordInfo) {
            .bytecode => |byte| {
                const id = byte & 0x7f;
                const named_callback = bytecodes.getCallbackById(id);
                if (named_callback.isImmediate) {
                    try self.interpretWord(wordInfo);
                } else {
                    // TODO
                }
            },
            .mini_word => |addr| {
                // TODO
                // if is immediate
                _ = addr;
                // try self.evaluateLoop();
            },
            .number => |value| {
                // TODO
                _ = value;
            },
        }
    }

    // TODO rename this
    pub fn consumeWord(self: *@This(), word: []const u8) Error!void {
        if (try self.lookupWord(word)) |word_info| {
            const state: CompileState = @enumFromInt(self.state.fetch());
            switch (state) {
                .interpret => {
                    try self.interpretWord(word_info);
                },
                .compile => {
                    try self.compileWord(word_info);
                },
            }
        }
    }

    pub fn repl(self: *@This()) Error!void {
        while (!self.should_bye) {
            self.should_quit = false;
            try self.input_source.refill();

            while (!self.should_quit and !self.should_bye) {
                const word = try self.input_source.readNextWord();
                if (word) |w| {
                    try self.consumeWord(w);
                } else {
                    self.should_quit = true;
                }
            }

            try self.onQuit();
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

    fn evaluateLoop(self: *@This()) Error!void {
        // Evalutation strategy:
        //   1. increment PC, then
        //   2. evaluate byte at PC-1
        // this makes return stack and jump logic easier
        //   because bytecodes can just set the jump location
        //     directly without having to do any math
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
        self.here.alignForward(Cell);
        const aligned_here = self.here.fetch();
        self.latest.store(aligned_here);
        try word_header.writeToMemory(
            self.memory[aligned_here..][0..header_size],
        );
        self.here.storeAdd(header_size);
        self.here.alignForward(Cell);
    }
};

test "mini" {
    // defineWordHeader
    //     check here, latest, memory
}
