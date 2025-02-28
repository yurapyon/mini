const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const mem = @import("memory.zig");
const bytecodes = @import("bytecodes.zig");

const MemoryLayout = @import("utils/memory-layout.zig").MemoryLayout;

const externals = @import("externals.zig");
const External = externals.External;

// ===

pub const Cell = u16;
pub const DoubleCell = u32;
pub const SignedCell = i16;

// TODO copy layout from Starting Forth
pub const RAMLayout = MemoryLayout(struct {
    program_counter: Cell,
    current_token_addr: Cell,
    data_stack_ptr: Cell,
    return_stack_ptr: Cell,
    execute_register: [2]Cell,
    dictionary_start: u0,

    _: u0,

    data_stack: u0,
    input_buffer: [128]u8,
    _rs_space: [64]Cell,
    return_stack: u0,
    b0: [1024]u8,
    b1: [1024]u8,
});

pub const Kernel = struct {
    allocator: Allocator,

    memory: mem.MemoryPtr,
    externals: ArrayList(External),

    program_counter: *Cell,
    current_token_addr: *Cell,
    data_stack_ptr: *Cell,
    return_stack_ptr: *Cell,
    execute_register: *Cell,

    pub fn init(self: *@This(), allocator: Allocator) !void {
        self.memory = try mem.allocateMemory(allocator);
        self.externals = ArrayList(External).init(allocator);

        self.program_counter = try mem.cellPtr(RAMLayout.offsetOf("program_counter"));
        self.current_token_addr = try mem.cellPtr(RAMLayout.offsetOf("current_token_addr"));
        self.data_stack_ptr = try mem.cellPtr(RAMLayout.offsetOf("data_stack_ptr"));
        self.return_stack_ptr = try mem.cellPtr(RAMLayout.offsetOf("return_stack_ptr"));
        self.execute_register = try mem.cellPtr(RAMLayout.offsetOf("execute_register"));
    }

    pub fn deinit(self: *@This()) void {
        // TODO free memory
        _ = self;
    }

    pub fn load(self: *@This(), data: []u8) void {
        _ = self;
        _ = data;
        // @memcpy(self.memory, self.data)
    }

    pub fn setCfaToExecute(self: *@This(), cfa_addr: Cell) void {
        self.execute_register.* = cfa_addr;
    }

    // Assumes the execute register is set
    pub fn execute(self: *@This()) !void {
        self.return_stack.pushCell(0);
        self.program_counter = RAMLayout.offsetOf("execute_register");

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
            if (bytecodes.getBytecode(token)) |callback| {
                // TODO handle errors here
                try callback(self);
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

    // TODO
    // this could take an offset?
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
