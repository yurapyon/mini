const std = @import("std");

const vm = @import("mini.zig");

/// A register is basically a pointer into VM Memory
/// The memory the register is stored in is passed in for all functions
pub const Register = struct {
    offset: vm.Cell,

    /// Won't crash as long as self.offset is aligned and within memory
    pub fn store(
        self: @This(),
        memory: vm.mem.CellAlignedMemory,
        value: vm.Cell,
    ) void {
        (vm.mem.cellAt(memory, self.offset) catch unreachable).* = value;
    }

    /// Won't crash as long as self.offset is aligned and within memory
    pub fn fetch(
        self: @This(),
        memory: vm.mem.CellAlignedMemory,
    ) vm.Cell {
        return (vm.mem.cellAt(memory, self.offset) catch unreachable).*;
    }

    /// Won't crash as long as self.offset is aligned and within memory
    pub fn storeAdd(
        self: @This(),
        memory: vm.mem.CellAlignedMemory,
        value: vm.Cell,
    ) void {
        (vm.mem.cellAt(memory, self.offset) catch unreachable).* +%= value;
    }

    /// Won't crash as long as self.offset is aligned and within memory
    pub fn storeSubtract(
        self: @This(),
        memory: vm.mem.CellAlignedMemory,
        value: vm.Cell,
    ) void {
        (vm.mem.cellAt(memory, self.offset) catch unreachable).* -%= value;
    }

    /// May error if self.fetch() is not cell aligned and within write_to
    /// Won't crash as long as self.offset is cell aligned and within memory
    pub fn comma(
        self: @This(),
        memory: vm.mem.CellAlignedMemory,
        write_to: vm.mem.CellAlignedMemory,
        value: vm.Cell,
    ) vm.mem.MemoryError!void {
        (try vm.mem.cellAt(write_to, self.fetch(memory))).* = value;
        self.storeAdd(memory, @sizeOf(vm.Cell));
    }

    /// Won't crash as long as self.offset is cell aligned and within memory
    pub fn alignForward(
        self: @This(),
        memory: vm.mem.CellAlignedMemory,
        alignment: vm.Cell,
    ) void {
        self.store(memory, std.mem.alignForward(vm.Cell, self.fetch(memory), alignment));
    }

    /// Won't crash as long as self.offset is within memory
    pub fn storeC(self: @This(), memory: []u8, value: u8) void {
        const byte = vm.mem.checkedAccess(
            memory,
            self.offset,
        ) catch unreachable;
        byte.* = value;
    }

    /// Won't crash as long as self.offset is within memory
    pub fn fetchC(self: @This(), memory: []u8) u8 {
        const byte = vm.mem.checkedRead(
            memory,
            self.offset,
        ) catch unreachable;
        return byte;
    }

    /// Won't crash as long as self.offset is within memory
    pub fn storeAddC(self: @This(), memory: []u8, value: u8) void {
        const byte = vm.mem.checkedAccess(memory, self.offset) catch unreachable;
        byte.* +%= value;
    }

    /// May error if self.fetch() is not within write_to
    /// Won't crash as long as self.offset is within memory
    pub fn commaC(
        self: @This(),
        memory: vm.mem.CellAlignedMemory,
        write_to: []u8,
        value: u8,
    ) vm.mem.MemoryError!void {
        const byte = try vm.mem.checkedAccess(write_to, self.fetch(memory));
        byte.* = value;
        self.storeAdd(memory, 1);
    }

    /// May error if self.fetch() is not within read_from
    /// Won't crash as long as self.offset is within memory
    pub fn readByteAndAdvance(
        self: @This(),
        memory: vm.mem.CellAlignedMemory,
        read_from: []const u8,
    ) vm.mem.MemoryError!u8 {
        const addr = self.fetch(memory);
        self.storeAdd(memory, 1);
        return try vm.mem.checkedRead(read_from, addr);
    }

    /// May error if self.fetch()+1 is not within read_from
    /// Won't crash as long as self.offset is within memory
    pub fn readCellAndAdvance(
        self: *@This(),
        memory: vm.mem.CellAlignedMemory,
        read_from: []const u8,
    ) vm.mem.MemoryError!vm.Cell {
        const low = try self.readByteAndAdvance(memory, read_from);
        const high = try self.readByteAndAdvance(memory, read_from);
        return @as(vm.Cell, high) << 8 | low;
    }
};

test "registers" {
    const testing = @import("std").testing;

    const memory = try vm.mem.allocateCellAlignedMemory(
        testing.allocator,
        vm.max_memory_size,
    );
    defer testing.allocator.free(memory);

    const reg_a = Register{ .offset = 0 };
    const reg_b = Register{ .offset = 2 };

    reg_a.store(memory, 0xdead);
    reg_b.store(memory, 0xbeef);
    try testing.expectEqualSlices(u8, &[_]u8{ 0xad, 0xde, 0xef, 0xbe }, memory[0..4]);

    reg_a.storeAdd(memory, 0x1111);
    reg_b.storeAdd(memory, 0x2222);
    try testing.expectEqualSlices(u8, &[_]u8{ 0xbe, 0xef, 0x11, 0xe1 }, memory[0..4]);

    try testing.expectEqual(0xefbe, reg_a.fetch(memory));

    const here = Register{ .offset = 0 };
    here.store(memory, 2);
    try here.comma(memory, memory, 0xadde);
    try here.comma(memory, memory, 0xefbe);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x06, 0x00, 0xde, 0xad, 0xbe, 0xef }, memory[0..6]);

    here.storeC(memory, 2);
    try here.commaC(memory, memory, 0xab);
    try here.commaC(memory, memory, 0xcd);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x04, 0x00, 0xab, 0xcd, 0xbe, 0xef }, memory[0..6]);

    try testing.expectEqual(0x04, here.fetchC(memory));
    here.storeAddC(memory, 1);
    try testing.expectEqual(0x05, here.fetchC(memory));
    here.alignForward(memory, @alignOf(vm.Cell));
    try testing.expectEqual(0x06, here.fetchC(memory));
}
