const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const builtin = @import("builtin");

const mem = @import("memory.zig");
const bytecodes = @import("bytecodes.zig");

const MemoryLayout = @import("utils/memory-layout.zig").MemoryLayout;

const stack = @import("stack.zig");
const Stack = stack.Stack;

const register = @import("register.zig");
const Register = register.Register;

// ===

// TODO
// might be nice to figure out a way to exit out early of
//   scripts that are being evaluated

comptime {
    const native_endianness = builtin.target.cpu.arch.endian();
    if (native_endianness != .little) {
        @compileError("native endianness must be .little");
    }
}

pub const Cell = u16;
pub const DoubleCell = u32;
pub const SignedCell = i16;
pub const SignedDoubleCell = i32;

pub fn cellFromBoolean(value: bool) Cell {
    return if (value) 0xffff else 0;
}

pub fn isTruthy(value: Cell) bool {
    return value != 0;
}

pub const block_size = 1024;
pub const block_count = 256;

pub const EoF = 0xffff;

pub const RAMLayout = MemoryLayout(struct {
    program_counter: Cell,
    current_token_addr: Cell,
    data_stack_ptr: Cell,
    return_stack_ptr: Cell,
    execute_register: [2]Cell,
    init_xt: Cell,
    dictionary_start: u0,

    _: u0,

    data_stack: u0,
    input_buffer: [128]u8,
    _rs_space: [64]Cell,
    return_stack: u0,
    // NOTE
    // rs can't end at mem = 65536 or address ranges don't work
    _rs_top_space: Cell,
});

pub const FFI = struct {
    pub const Error = error{
        UnhandledExternal,
    } || bytecodes.Error;

    pub const Callback =
        *const fn (k: *Kernel, userdata: ?*anyopaque, id: Cell) Error!void;

    pub const Lookup =
        *const fn (k: *Kernel, userdata: ?*anyopaque, name: []const u8) ?Cell;

    pub const Closure = struct {
        callback: Callback,
        lookup: Lookup,
        userdata: ?*anyopaque,
    };
};

pub const Accept = struct {
    pub const Error = error{
        CannotAccept,
    } || bytecodes.Error;

    pub const Callback = *const fn (
        k: *Kernel,
        userdata: ?*anyopaque,
        buf_addr: Cell,
        buf_len: Cell,
    ) Error!Cell;

    // NOTE
    // If accept is async, before resuming callback should:
    //   fill the output memory at addr, accounting for max_len
    //   push string size to the stack
    pub const Closure = struct {
        callback: Callback,
        userdata: ?*anyopaque,
        is_async: bool,
    };
};

pub const Emit = struct {
    pub const Callback =
        *const fn (char: u8, userdata: ?*anyopaque) void;

    pub const Closure = struct {
        callback: Callback,
        userdata: ?*anyopaque,
    };
};

const ExecutionStatus = enum {
    playing,
    paused,
    resuming,
};

pub const Kernel = struct {
    memory: mem.MemoryPtr,
    execution_status: ExecutionStatus,

    debug_accept_buffer: bool,
    accept_buffer: ?struct {
        stream: std.io.FixedBufferStream([]const u8),
        mem: []const u8,
    },

    accept_closure: ?Accept.Closure,
    emit_closure: ?Emit.Closure,
    ffi_closure: ?FFI.Closure,

    program_counter: Register(
        RAMLayout.offsetOf("program_counter"),
    ),
    current_token_addr: Register(
        RAMLayout.offsetOf("current_token_addr"),
    ),
    execute_register: Register(
        RAMLayout.offsetOf("execute_register"),
    ),
    init_xt: Register(
        RAMLayout.offsetOf("init_xt"),
    ),
    data_stack: Stack(
        RAMLayout.offsetOf("data_stack_ptr"),
        RAMLayout.offsetOf("data_stack"),
    ),
    return_stack: Stack(
        RAMLayout.offsetOf("return_stack_ptr"),
        RAMLayout.offsetOf("return_stack"),
    ),

    debug: struct {
        enable_tco: bool,
        exec_counter: Cell,
    },

    pub fn init(
        self: *@This(),
        memory: mem.MemoryPtr,
    ) void {
        self.memory = memory;
        self.execution_status = .playing;

        self.program_counter.init(self.memory);
        self.current_token_addr.init(self.memory);
        self.execute_register.init(self.memory);
        self.init_xt.init(self.memory);

        self.data_stack.init(self.memory);
        self.return_stack.init(self.memory);

        self.debug_accept_buffer = true;
        self.accept_buffer = null;

        self.debug.enable_tco = true;
        self.debug.exec_counter = 0;
    }

    pub fn clear(self: *@This()) void {
        for (self.memory) |*byte| {
            byte.* = 0xaa;
        }
    }

    pub fn loadImage(self: *@This(), data: []u8) void {
        self.clear();
        @memcpy(self.memory[0..data.len], data);
        self.data_stack.initTopPtr();
        self.return_stack.initTopPtr();
    }

    pub fn initForth(self: *@This()) void {
        // TODO
        //   should set 'stay' to true??
        //   should set exec_state to .playing?
        const init_xt = self.init_xt.fetch();
        self.execute_register.store(init_xt);
    }

    // TODO this function is confusing, can probably get rid of it
    pub fn setCfaToExecute(self: *@This(), cfa_addr: Cell) void {
        self.execute_register.store(cfa_addr);
        self.program_counter.store(@TypeOf(self.execute_register).offset);
    }

    pub fn execute(self: *@This()) !void {
        // TODO maybe move this out of here somehow
        switch (self.execution_status) {
            .playing => {
                self.return_stack.pushCell(0);
                self.program_counter.store(@TypeOf(self.execute_register).offset);
            },
            .paused => return,
            .resuming => {
                self.execution_status = .playing;
            },
        }

        // Execution strategy:
        //   1. increment PC, then
        //   2. evaluate byte at PC-1
        // this makes return stack and jump logic easier
        //   because bytecodes can just set the jump location
        //     directly without having to do any math

        while (self.program_counter.fetch() != 0) {
            self.debug.exec_counter +%= 1;

            const token_addr = try mem.readCell(
                self.memory,
                self.program_counter.fetch(),
            );
            self.current_token_addr.store(token_addr);
            try self.advancePC(@sizeOf(Cell));

            // TODO
            // print more debug info

            const token = mem.readCell(self.memory, token_addr) catch |err| {
                const message = switch (err) {
                    error.MisalignedAddress => "Misaligned Address",
                };

                // TODO
                // some type of "report error" callback instad of std.debug
                if (builtin.target.cpu.arch != .wasm32) {
                    std.debug.print("Token Lookup Error: {s}\n", .{message});
                }
                self.abort();

                continue;
            };

            if (bytecodes.getBytecode(token)) |callback| {
                callback(self) catch |err| {
                    // TODO err -> string function
                    const message = switch (err) {
                        error.Panic => "Panic",
                        error.InvalidProgramCounter => "Invalid Program Counter",
                        error.OutOfBounds => "Out of Bounds",
                        error.MisalignedAddress => "Misaligned Address",
                        error.CannotAccept => "Cannot Accept",
                        error.CannotEmit => "Cannot Emit",
                        error.StackUnderflow => "Stack Underflow",
                    };

                    const name = bytecodes.getBytecodeName(token) orelse "Unknown";

                    // TODO
                    // some type of "report error" callback instad of std.debug
                    if (builtin.target.cpu.arch != .wasm32) {
                        std.debug.print("Error: {s}, Word: {s}\n", .{ message, name });
                    }
                    self.abort();
                };
            } else {
                const ext_token = token - @as(Cell, @intCast(bytecodes.bytecode_count));
                self.processFFI(ext_token) catch |err| {
                    const message = switch (err) {
                        error.Panic => "Panic",
                        error.InvalidProgramCounter => "Invalid Program Counter",
                        error.OutOfBounds => "Out of Bounds",
                        error.MisalignedAddress => "Misaligned Address",
                        error.CannotAccept => "Cannot Accept",
                        error.CannotEmit => "Cannot Emit",
                        error.StackUnderflow => "Stack Underflow",
                        error.UnhandledExternal => "Unhandled External",
                    };

                    _ = message;

                    // const name = self.externals[ext_token].name;

                    // TODO
                    // some type of "report error" callback instad of std.debug
                    if (builtin.target.cpu.arch != .wasm32) {
                        // std.debug.print("External error: {s}, Word: {s}\n", .{ message, name });
                    }

                    self.abort();
                };
            }

            if (self.execution_status == .paused) {
                break;
            }
        }
    }

    pub fn assertValidProgramCounter(self: @This()) !void {
        if (self.program_counter.fetch() == 0) {
            return error.InvalidProgramCounter;
        }
    }

    pub fn advancePC(self: *@This(), offset: Cell) !void {
        try mem.assertOffsetInBounds(self.program_counter.fetch(), offset);
        self.program_counter.storeAdd(offset);
    }

    pub fn pushReturnAddr(self: *@This()) !void {
        // NOTE
        //   if k.pc.fetch().* === exit, then you don't need to push pc to the return stack
        // but you need to make sure that:
        //   everywhere raw data is compiled into a definition, its preceded by a builtin
        //   (something when dereferenced isn't docol)

        const pc = self.program_counter.fetch();
        const token_at_pc = try mem.readCell(self.memory, pc);
        const deref = try mem.readCell(self.memory, token_at_pc);
        const exit_code = bytecodes.getExitCode();
        if (!(self.debug.enable_tco and deref == exit_code)) {
            self.return_stack.pushCell(pc);
        }
    }

    pub fn pause(self: *@This()) void {
        self.execution_status = .paused;
    }

    pub fn unpause(self: *@This()) void {
        self.execution_status = .resuming;
    }

    // ===

    fn processFFI(self: *@This(), ext_token: Cell) !void {
        if (self.ffi_closure) |ffi| {
            try ffi.callback(self, ffi.userdata, ext_token);
        } else {
            // TODO
            // return error.CannotFFI
            return error.UnhandledExternal;
        }
    }

    pub fn lookupFFI(self: *@This(), name: []const u8) ?Cell {
        if (self.ffi_closure) |ffi| {
            return ffi.lookup(self, ffi.userdata, name);
        } else {
            // TODO return error here?
            return null;
        }
    }

    pub fn setFFIClosure(
        self: *@This(),
        closure: FFI.Closure,
    ) void {
        self.ffi_closure = closure;
    }

    pub fn clearFFIClosure(self: *@This()) void {
        self.ffi_closure = null;
    }

    // ===

    // TODO
    // This needs to be tested/reworked after buffer copying has been removed
    // NOTE
    // Buffer must stay in memory until clearAcceptBuffer is called
    pub fn setAcceptBuffer(
        self: *@This(),
        buffer: []const u8,
    ) !void {
        if (builtin.target.cpu.arch != .wasm32 and self.debug_accept_buffer) {
            std.debug.print(">> Accept buffer set:\n{s}...\n", .{buffer[0..@min(buffer.len, 128)]});
        }
        // const copied = try self.allocator.alloc(u8, buffer.len);
        // @memcpy(copied, buffer);
        // const const_copied: []const u8 = copied;
        self.accept_buffer = .{
            // .stream = std.io.fixedBufferStream(const_copied),
            .stream = std.io.fixedBufferStream(buffer),
            .mem = buffer,
        };
    }

    pub fn clearAcceptBuffer(self: *@This()) void {
        if (builtin.target.cpu.arch != .wasm32 and self.debug_accept_buffer) {
            std.debug.print(">> Accept buffer cleared\n", .{});
        }
        self.accept_buffer = null;
    }

    pub fn setAcceptClosure(
        self: *@This(),
        closure: Accept.Closure,
    ) void {
        self.accept_closure = closure;
    }

    pub fn clearAcceptClosure(self: *@This()) void {
        self.accept_closure = null;
    }

    pub fn setEmitClosure(
        self: *@This(),
        closure: Emit.Closure,
    ) void {
        self.emit_closure = closure;
    }

    pub fn clearEmitClosure(self: *@This()) void {
        self.emit_closure = null;
    }

    // ===

    pub fn evaluate(self: *@This(), str: []const u8) !void {
        try self.setAcceptBuffer(str);
        self.initForth();
        try self.execute();
    }

    pub fn abort(self: *@This()) void {
        // TODO
        // maybe this should stop accepting the current file ?
        // could print return stack

        const init_xt = self.init_xt.fetch();

        self.return_stack.clear();
        self.return_stack.pushCell(0);
        self.setCfaToExecute(init_xt);
    }
};
