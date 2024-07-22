const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const bytecodes = @import("bytecodes.zig");
const Devices = @import("devices/Devices.zig").Devices;
const Stack = @import("Stack.zig").Stack;
const MemoryWithLayout = @import("MemoryWithLayout.zig").MemoryWithLayout;

comptime {
    const nativeEndianness = builtin.target.cpu.arch.endian();
    if (nativeEndianness != .little) {
        // TODO convert u16s to little endian on memory write
        @compileError("native endianness must be .little");
    }
}

pub const Error = error{
    AlignmentError,
    StackOverflow,
    StackUnderflow,
    ReturnStackOverflow,
    ReturnStackUnderflow,
    WordNotFound,
} || Allocator.Error;

pub fn returnStackErrorFromStackError(err: Error) Error {
    return switch (err) {
        Error.StackOverflow => Error.ReturnStackOverflow,
        Error.StackUnderflow => Error.ReturnStackUnderflow,
        else => err,
    };
}

const CompileState = enum(Cell) {
    interpret = 0,
    compile,
    bytecode,
    system,
};

const DataStack = Stack(32);
const ReturnStack = Stack(32);

pub const Memory = MemoryWithLayout(struct {
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
});

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

pub fn tryParseNumber(str: []const u8) ?Cell {
    // TODO
    _ = str;
    return null;
}

pub const WordHeader = struct {
    previousHeader: Cell,
    name: []const u8,
    isImmediate: bool,
    isHidden: bool,
};

pub const MiniVM = struct {
    const mem_size = 64 * 1024;

    memory: Memory,

    program_counter: *Cell,
    data_stack: DataStack,
    return_stack: ReturnStack,
    here: *Cell,
    latest: *Cell,
    state: *Cell,
    base: *Cell,
    active_device: *Cell,

    // TODO move this into a device
    input_buffer: []const u8,
    input_buffer_at: usize,

    devices: Devices,

    pub fn init(self: *@This(), allocator: Allocator) !void {
        try self.memory.init(allocator, mem_size);

        self.program_counter = self.memory.atLayout(Cell, "program_counter");
        self.data_stack.init(
            &self.memory,
            self.memory.atLayout(Cell, "data_stack_top"),
            self.memory.atLayout(Cell, "data_stack"),
        );
        self.return_stack.init(
            &self.memory,
            self.memory.atLayout(Cell, "return_stack_top"),
            self.memory.atLayout(Cell, "return_stack"),
        );
        self.here = self.memory.atLayout(Cell, "here");
        self.latest = self.memory.atLayout(Cell, "latest");
        self.state = self.memory.atLayout(Cell, "state");
        self.base = self.memory.atLayout(Cell, "base");
        self.active_device = self.memory.atLayout(Cell, "active_device");

        self.here.* = 0;
        self.latest.* = 0;
        self.state.* = 0;
        self.base.* = 10;
        self.active_device.* = 0;

        // TODO
        // run base file
    }

    pub fn deinit(self: @This()) void {
        self.memory.deinit();
    }

    // ===

    pub fn quit(self: *@This()) Error!void {
        _ = self;
        // reset stack
        // quit to repl
    }

    pub fn bye(self: *@This()) Error!void {
        try self.quit();
        // quit the entire process (what does that mean in this context)
    }

    // ===

    pub fn setInputBuffer(self: *@This(), buffer: []const u8) void {
        self.input_buffer = buffer;
        self.input_buffer_at = 0;
    }

    pub fn readNextChar(self: *@This()) ?u8 {
        if (self.input_buffer_at < self.input_buffer.len - 1) {
            self.input_buffer_at += 1;
            return self.input_buffer[self.input_buffer_at];
        } else {
            return null;
        }
    }

    pub fn readNextWord(self: *@This()) ?[]const u8 {
        var char = self.readNextChar() orelse return null;

        while (isWhitespace(char)) {
            char = self.readNextChar() orelse return null;
        }

        const word_start = self.input_buffer_at;

        var word_end = word_start;
        while (isWhitespace(char)) {
            if (self.readNextChar()) |ch| {
                char = ch;
                word_end += 1;
            } else {
                break;
            }
        }

        return self.input_buffer[word_start..word_end];
    }

    // returns memory mapped addr
    fn lookupMiniDefinition(self: *@This(), word: []const u8) ?Cell {
        // TODO
        _ = self;
        _ = word;
        return null;
    }

    fn lookupWord(self: *@This(), word: []const u8) Error!WordLookupResult {
        if (bytecodes.getCallbackBytecode(word)) |bytecode| {
            return .{ .bytecode = bytecode };
        } else if (self.lookupMiniDefinition(word)) |definition_addr| {
            return .{ .mini_word = definition_addr };
        } else if (tryParseNumber(word)) |value| {
            return .{ .number = value };
        } else {
            return WordLookupResult.not_found;
        }
    }

    fn interpretWord(self: *@This(), word: []const u8) Error!void {
        // note there are some bytecodes that only make sense to be compiled
        //   ie lit, litc, branch
        // TODO how to handle this
        switch (try self.lookupWord(word)) {
            .bytecode => |byte| {
                // if byte.shouldInterpret
                try self.evaluateByte(byte);
            },
            .mini_word => |addr| {
                // TODO get the cfa of the definition at addr
                try self.absoluteJump(addr, false);
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
                _ = byte;
            },
            .mini_word => |addr| {
                _ = addr;
            },
            .number => |value| {
                _ = value;
            },
            .not_found => return Error.WordNotFound,
        }
    }

    pub fn interpretLoop(self: *@This()) Error!void {
        var out_of_input = false;
        while (!out_of_input) {
            const state: CompileState = @enumFromInt(self.state.*);
            switch (state) {
                .interpret => {
                    const word = self.readNextWord();
                    if (word) |w| {
                        try self.interpretWord(w);
                    } else {
                        out_of_input = true;
                    }
                },
                .compile => {
                    const word = self.readNextWord();
                    if (word) |w| {
                        try self.compileWord(w);
                    } else {
                        out_of_input = true;
                    }
                },
                // TODO
                else => {
                    unreachable;
                },
            }
        }
    }

    pub fn readByteAndAdvancePC(self: *@This()) u8 {
        const pc_at = self.program_counter.*;
        // TODO handle reaching end of memory
        self.program_counter.* += 1;
        return self.memory.byteAt(pc_at).*;
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
            try self.return_stack.push(self.program_counter.*);
        }
        self.program_counter.* = addr;
    }

    // NOTE
    // evalutation strategy
    //   1. increment pc, then
    //   2. evaluate byte at pc-1
    // this makes return stack and jump logic easier

    fn evaluateOne(self: *@This()) Error!void {
        const byte = self.readByteAndAvancePC();
        self.evaluateByte(byte);
    }

    // program_counter may be moved
    fn evaluateByte(self: *@This(), byte: u8) Error!void {
        switch (byte) {
            inline 0b00000000...0b01101111 => |b| {
                const id = b & 0x7f;
                const named_callback = bytecodes.getCallbackById(id);
                try named_callback.callback(self);
            },
            inline 0b01110000...0b01111111 => |b| {
                // TODO how should endianness be handled for this
                const high = b & 0x0f;
                const low = self.readByteAndAdvancePC();
                const addr = self.program_counter.*;
                const length = @as(Cell, high) << 8 | low;
                try self.data_stack.push(addr);
                try self.data_stack.push(length);
                self.program_counter.* += length;
            },
            inline 0b10000000...0b11111111 => |b| {
                // TODO how should endianness be handled for this
                const high = b & 0x7f;
                const low = self.readByteAndAdvancePC();
                const addr = @as(Cell, high) << 8 | low;
                try self.absoluteJump(addr, true);
            },
        }
    }

    fn defineWordHeader(self: *@This(), word_header: WordHeader) void {
        // TODO
        _ = self;
        _ = word_header;
    }
};
