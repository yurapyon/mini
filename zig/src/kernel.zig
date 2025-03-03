const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

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

pub const Cell = u16;
pub const DoubleCell = u32;
pub const SignedCell = i16;

const block_size = 1024;
const block_count = 256;

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
    b0_id: Cell,
    b0_upd: Cell,
    b0: [block_size]u8,
    b1_id: Cell,
    b1_upd: Cell,
    b1: [block_size]u8,
    // NOTE
    // b1 can't end at mem = 65536 or address ranges don't work
    bswapped: Cell,
});

pub const Kernel = struct {
    allocator: Allocator,

    memory: mem.MemoryPtr,
    externals: ArrayList(External),

    input_file: std.fs.File,
    output_file: std.fs.File,

    block_image_filepath: []const u8,

    accept_buffer: ?struct {
        mem: []const u8,
        at: usize,
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
    data_stack: Stack(
        RAMLayout.offsetOf("data_stack_ptr"),
        RAMLayout.offsetOf("data_stack"),
    ),
    return_stack: Stack(
        RAMLayout.offsetOf("return_stack_ptr"),
        RAMLayout.offsetOf("return_stack"),
    ),

    pub fn init(
        self: *@This(),
        allocator: Allocator,
        block_image_filepath: []const u8,
    ) !void {
        self.input_file = std.io.getStdIn();
        self.output_file = std.io.getStdOut();

        self.memory = try mem.allocateMemory(allocator);
        self.externals = ArrayList(External).init(allocator);

        self.program_counter.init(self.memory);
        self.current_token_addr.init(self.memory);
        self.execute_register.init(self.memory);

        self.data_stack.init(self.memory);
        self.return_stack.init(self.memory);

        self.block_image_filepath = block_image_filepath;
        self.accept_buffer = null;
    }

    pub fn deinit(self: *@This()) void {
        // TODO free memory
        _ = self;
    }

    pub fn clear(self: *@This()) void {
        for (self.memory) |*byte| {
            byte.* = 0xaa;
        }
    }

    pub fn load(self: *@This(), data: []u8) void {
        self.clear();
        @memcpy(self.memory[0..data.len], data);
        self.data_stack.initTopPtr();
        self.return_stack.initTopPtr();
    }

    pub fn setCfaToExecute(self: *@This(), cfa_addr: Cell) void {
        self.execute_register.store(cfa_addr);
        self.program_counter.store(@TypeOf(self.execute_register).offset);
    }

    pub fn execute(self: *@This()) !void {
        self.return_stack.pushCell(0);
        self.program_counter.store(@TypeOf(self.execute_register).offset);

        // std.debug.print("here {}\n", .{self.program_counter.fetch()});

        // Execution strategy:
        //   1. increment PC, then
        //   2. evaluate byte at PC-1
        // this makes return stack and jump logic easier
        //   because bytecodes can just set the jump location
        //     directly without having to do any math

        while (self.program_counter.fetch() != 0) {
            const token_addr = try mem.readCell(
                self.memory,
                self.program_counter.fetch(),
            );
            self.current_token_addr.store(token_addr);
            try self.advancePC(@sizeOf(Cell));

            // std.debug.print("loop {} {}\n", .{
            // token_addr,
            // self.program_counter.fetch(),
            // });

            const token = try mem.readCell(self.memory, token_addr);

            // std.debug.print("loop {}\n", .{ token });

            if (bytecodes.getBytecode(token)) |callback| {
                // std.debug.print("x {}\n", .{callback});
                // TODO handle abort" errors here
                try callback(self);
            } else {
                // TODO
                try self.processExternals(token);
            }
        }
    }

    pub fn assertValidProgramCounter(self: @This()) !void {
        if (self.program_counter.fetch() == 0) {
            return error.InvalidProgramCounter;
        }
    }

    pub fn advancePC(self: *@This(), offset: Cell) !void {
        // std.debug.print("{}\n", .{self.program_counter.fetch()});
        try mem.assertOffsetInBounds(self.program_counter.fetch(), offset);
        self.program_counter.storeAdd(offset);
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

    // blocks ===

    pub fn storageToBlock(
        self: *@This(),
        block_id: Cell,
        buffer: []u8,
    ) !void {
        if (block_id > block_count) {
            return error.InvalidBlockId;
        }

        // TODO check block size

        var file = try std.fs.cwd().openFile(
            self.block_image_filepath,
            .{ .mode = .read_only },
        );
        defer file.close();

        // TODO
        // check file size ?
        const seek_pt: usize = (block_id - 1) * block_size;
        try file.seekTo(seek_pt);
        _ = try file.read(buffer);
    }

    pub fn blockToStorage(
        self: *@This(),
        block_id: Cell,
        buffer: []const u8,
    ) !void {
        if (block_id > block_count) {
            return error.InvalidBlockId;
        }

        // TODO check block size

        var file = try std.fs.cwd().openFile(
            self.block_image_filepath,
            .{ .mode = .write_only },
        );
        defer file.close();

        // TODO
        // check file size ?
        const seek_pt: usize = (block_id - 1) * block_size;
        try file.seekTo(seek_pt);
        _ = try file.write(buffer);
    }
};
