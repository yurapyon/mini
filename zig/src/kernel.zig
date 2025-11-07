const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const builtin = @import("builtin");

const mem = @import("memory.zig");
const bytecodes = @import("bytecodes.zig");

const MemoryLayout = @import("utils/memory-layout.zig").MemoryLayout;

const externals = @import("externals.zig");
const External = externals.External;

const stack = @import("stack.zig");
const Stack = stack.Stack;

const register = @import("register.zig");
const Register = register.Register;

// ===

comptime {
    const native_endianness = builtin.target.cpu.arch.endian();
    if (native_endianness != .little) {
        @compileError("native endianness must be .little");
    }
}

pub const Cell = u16;
pub const DoubleCell = u32;
pub const SignedCell = i16;

pub fn cellFromBoolean(value: bool) Cell {
    return if (value) 0xffff else 0;
}

pub fn isTruthy(value: Cell) bool {
    return value != 0;
}

pub const block_size = 1024;
pub const block_count = 256;

pub const EoF = 0xffff;

const NamedExternal = struct {
    name: []const u8,
    external: External,
};

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

pub const AcceptCallback =
    *const fn (out: []u8, userdata: ?*anyopaque) error{CannotAccept}!Cell;

pub const EmitCallback =
    *const fn (char: u8, userdata: ?*anyopaque) void;

pub const Kernel = struct {
    allocator: Allocator,

    memory: mem.MemoryPtr,
    externals: ArrayList(NamedExternal),

    debug_accept_buffer: bool,
    accept_buffer: ?struct {
        stream: std.io.FixedBufferStream([]const u8),
        mem: []const u8,
    },

    accept_closure: ?struct {
        callback: AcceptCallback,
        userdata: ?*anyopaque,
    },

    emit_closure: ?struct {
        callback: EmitCallback,
        userdata: ?*anyopaque,
    },

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
        allocator: Allocator,
    ) !void {
        self.allocator = allocator;

        self.memory = try mem.allocateMemory(allocator);
        self.externals = .empty;

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

    pub fn deinit(self: *@This()) void {
        self.externals.deinit(self.allocator);
        self.allocator.free(self.memory);
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
        const init_xt = self.init_xt.fetch();
        self.execute_register.store(init_xt);
    }

    // TODO this function is confusing, can probably get rid of it
    pub fn setCfaToExecute(self: *@This(), cfa_addr: Cell) void {
        self.execute_register.store(cfa_addr);
        self.program_counter.store(@TypeOf(self.execute_register).offset);
    }

    pub fn execute(self: *@This()) !void {
        self.return_stack.pushCell(0);
        self.program_counter.store(@TypeOf(self.execute_register).offset);

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

            const token = try mem.readCell(self.memory, token_addr);

            if (bytecodes.getBytecode(token)) |callback| {
                try callback(self);
            } else {
                const ext_token = token - @as(Cell, @intCast(bytecodes.callbacks.len));
                try self.processExternals(ext_token);
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

    // Sets up 'xt' for execution, finishes execution of xt before returning
    pub fn callXt(self: *@This(), xt: Cell) !void {
        self.return_stack.pushCell(self.program_counter.fetch());
        self.setCfaToExecute(xt);
        try self.execute();
        self.program_counter.store(self.return_stack.popCell());
    }

    pub fn pushReturnAddr(self: *@This()) !void {
        // TODO this seems to work but theres a chance it doesnt

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

    // ===

    pub fn addExternal(self: *@This(), name: []const u8, external: External) !void {
        // TODO check that this id isn't > maxInt(cell)
        try self.externals.append(self.allocator, .{
            .name = name,
            .external = external,
        });
    }

    fn processExternals(self: *@This(), ext_token: Cell) !void {
        if (ext_token < self.externals.items.len) {
            try self.externals.items[ext_token].external.call(self);
        } else {
            std.debug.print("Unhandled external: {}\n", .{
                ext_token,
            });
            return error.UnhandledExternal;
        }
    }

    pub fn lookupExternal(self: *@This(), name: []const u8) ?Cell {
        for (self.externals.items, 0..) |namedExternal, i| {
            if (std.mem.eql(u8, namedExternal.name, name)) {
                return @intCast(i);
            }
        }

        return null;
    }

    // ===

    pub fn setAcceptBuffer(
        self: *@This(),
        buffer: []const u8,
    ) !void {
        if (self.debug_accept_buffer) {
            std.debug.print(">> Accept buffer set:\n{s}...\n", .{buffer[0..@min(buffer.len, 128)]});
        }
        const copied = try self.allocator.alloc(u8, buffer.len);
        @memcpy(copied, buffer);
        const const_copied: []const u8 = copied;
        self.accept_buffer = .{
            .stream = std.io.fixedBufferStream(const_copied),
            .mem = const_copied,
        };
    }

    pub fn clearAcceptBuffer(self: *@This()) void {
        if (self.debug_accept_buffer) {
            std.debug.print(">> Accept buffer cleared\n", .{});
        }
        if (self.accept_buffer) |buf| {
            self.allocator.free(buf.mem);
        }
        self.accept_buffer = null;
    }

    pub fn setAcceptClosure(
        self: *@This(),
        callback: AcceptCallback,
        userdata: ?*anyopaque,
    ) void {
        self.accept_closure = .{
            .callback = callback,
            .userdata = userdata,
        };
    }

    pub fn clearAcceptClosure(self: *@This()) void {
        self.accept_closure = null;
    }

    pub fn setEmitClosure(
        self: *@This(),
        callback: EmitCallback,
        userdata: ?*anyopaque,
    ) void {
        self.emit_closure = .{
            .callback = callback,
            .userdata = userdata,
        };
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
};
