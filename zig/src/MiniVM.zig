const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const bytecodes = @import("bytecodes.zig");
const Devices = @import("devices/Devices.zig").Devices;
const Stack = @import("Stack.zig").Stack;
const MemoryWithLayout = @import("Memory.zig").MemoryWithLayout;

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
} || Allocator.Error;

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

pub const Cell = u16;

pub fn cellFromBool(value: bool) Cell {
    return if (value) 0xffff else 0;
}

pub fn isTruthy(value: Cell) bool {
    return value != 0;
}

pub const BytecodeFn = *const fn (vm: *MiniVM) Error!void;

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

        try self.evaluateByte(0x60);
        // self.evaluateByte(0x70);
        // self.evaluateByte(0x80);
    }

    pub fn deinit(self: @This()) void {
        self.memory.deinit();
    }

    // ===

    // vm should operate as follows
    // 1. set input buffer
    // 2. interpret input buffer
    // input buffer is exposed to vm through a device

    pub fn setBuffer(_: *@This(), _: []u8) void {}

    pub fn interpret(_: *@This()) Error!void {}

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

    pub fn absJump(
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
                try self.absJump(addr, true);
            },
        }
    }

    fn compileWord(self: *@This(), word: []u8) void {
        // TODO
        _ = self;
        _ = word;
    }
};
