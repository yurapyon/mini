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
            inline 0b00000000...0b00111111 => |b| {
                const fn_idx = b & 0xcf;
                const lookup_table = [_]u8{
                    0,
                } ** 64;
                _ = lookup_table[fn_idx];
            },
            inline 0b01000000...0b01001111 => {
                // note: currently undefined
                unreachable;
            },
            inline 0b01010000...0b01010011 => |b| {
                const high: u16 = b & 0x03;
                self.program_counter.* += 1;
                const pc_at = self.program_counter.*;
                const low = self.memory[pc_at];
                const length = high << 8 | low;
                _ = length;
            },
            inline 0b01010100...0b01011111 => |b| {
                const action_id: u2 = (b & 0x0c) >> 2;
                const register_id: u2 = b & 0x3;
                _ = register_id;
                switch (action_id) {
                    inline 0b00 => {
                        unreachable;
                    },
                    inline 0b01 => {},
                    inline 0b10 => {},
                    inline 0b11 => {},
                }
            },
            inline 0b01100000...0b01100111 => |b| {
                const shift_amt = b & 0x7;
                const value = if (shift_amt == 7) 0 else 1 << shift_amt;
                _ = value;
            },
            inline 0b01101000...0b01101111 => |b| {
                const shift_amt = b & 0x7;
                const value: u16 = (1 << ((shift_amt + 1) * 2)) - 1;
                _ = value;
            },
            inline 0b01110000...0b01111111 => |b| {
                const device_id = b & 0xf;
                self.active_device.* = device_id;
                self.devices.activate(self, device_id);
            },
            inline 0b10000000...0b10111111 => |b| {
                const do_read = (b & 0x20) != 0;
                const register_addr = b & 0x1f;
                _ = register_addr;
                if (do_read) {
                    // TODO
                    // const value = self.devices.read(register_addr)
                    // push stack
                } else {
                    // TODO
                    // pop stack
                    // self.devices.write(register_addr, value)
                }
            },
            inline 0b11000000...0b11111111 => |b| {
                const high: u16 = b & 0x3f;
                self.program_counter.* += 1;
                const pc_at = self.program_counter.*;
                const low = self.memory[pc_at];
                const addr = high << 8 | low;
                // TODO manage return stack
                self.program_counter.* = addr;
            },
        }
    }
};
