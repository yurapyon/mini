const std = @import("std");
const Allocator = std.mem.Allocator;

const Devices = @import("devices/Devices.zig").Devices;

pub const MiniVM = struct {
    const Cell = u16;

    const cell_size = @sizeOf(Cell);
    const mem_size = 32 * 1024;

    fn Stack(comptime count_: usize) type {
        return struct {
            const count = count_;
            const size = count * cell_size;
            top: *Cell,
            mem: *Cell,

            fn init(self: *@This(), top: *Cell, mem: *Cell) void {
                self.top = top;
                self.mem = mem;
                self.clear();
            }

            fn clear(self: @This()) void {
                self.top.* = self.mem.*;
            }
        };
    }

    const DataStack = Stack(32);
    const ReturnStack = Stack(32);

    allocator: Allocator,
    memory: []u8,

    program_counter: *Cell,
    data_stack: DataStack,
    return_stack: ReturnStack,
    here: *Cell,
    latest: *Cell,
    state: *Cell,
    base: *Cell,
    active_device: *Cell,

    devices: Devices,

    const program_counter_mem = 0;
    const data_stack_top = program_counter_mem + cell_size;
    const data_stack_mem = data_stack_top + cell_size;
    const return_stack_top = data_stack_mem + DataStack.size;
    const return_stack_mem = return_stack_top + cell_size;
    const here_mem = return_stack_mem + cell_size;
    const latest_mem = here_mem + cell_size;
    const state_mem = latest_mem + cell_size;
    const base_mem = state_mem + cell_size;
    const active_device_mem = base_mem + cell_size;

    pub fn init(self: *@This(), allocator: Allocator) !void {
        self.allocator = allocator;
        self.memory = try allocator.allocWithOptions(u8, mem_size, @alignOf(Cell), null);

        self.program_counter = @ptrCast(@alignCast(&self.memory[program_counter_mem]));
        self.data_stack.init(@ptrCast(@alignCast(&self.memory[data_stack_top])), @ptrCast(@alignCast(&self.memory[data_stack_mem])));
        self.return_stack.init(@ptrCast(@alignCast(&self.memory[return_stack_top])), @ptrCast(@alignCast(&self.memory[return_stack_mem])));
        self.here = @ptrCast(@alignCast(&self.memory[here_mem]));
        self.latest = @ptrCast(@alignCast(&self.memory[latest_mem]));
        self.state = @ptrCast(@alignCast(&self.memory[state_mem]));
        self.base = @ptrCast(@alignCast(&self.memory[base_mem]));
        self.active_device = @ptrCast(@alignCast(&self.memory[active_device_mem]));

        self.evaluateByte(0x70);
        self.evaluateByte(0x80);
    }

    pub fn deinit(self: @This()) void {
        self.allocator.free(self.memory);
    }

    fn evaluateByte(self: *@This(), byte: u8) void {
        switch (byte) {
            inline 0...0x6f => {},
            inline 0x70...0x7f => |b| {
                const device_id = b & 0xf;
                self.active_device.* = device_id;
                self.devices.activate(self, device_id);
            },
            inline 0x80...0xff => {},
        }
    }
};
