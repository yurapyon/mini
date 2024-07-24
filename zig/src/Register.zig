const std = @import("std");

const vm = @import("mini.zig");

/// A register is basically a pointer into VM Memory
/// It's memory-mapped, rather than being a system pointer
///   so, an offset of 0 means memory[0]
pub const Register = struct {
    memory: vm.Memory,
    offset: vm.Cell,

    pub fn init(self: *@This(), memory: vm.Memory, offset: vm.Cell) void {
        self.memory = memory;
        self.offset = offset;
    }

    pub fn address(self: @This()) void {
        return self.offset;
    }

    fn accessCell(self: @This(), addr: usize) *vm.Cell {
        return @ptrCast(@alignCast(&self.memory[addr]));
    }

    pub fn store(self: @This(), value: vm.Cell) void {
        self.accessCell(self.offset).* = value;
    }

    pub fn storeAdd(self: @This(), value: vm.Cell) void {
        self.accessCell(self.offset).* +%= value;
    }

    pub fn storeSubtract(self: @This(), value: vm.Cell) void {
        self.accessCell(self.offset).* -%= value;
    }

    pub fn fetch(self: @This()) vm.Cell {
        return self.accessCell(self.offset).*;
    }

    pub fn comma(self: @This(), value: vm.Cell) void {
        self.accessCell(self.fetch()).* = value;
        self.storeAdd(@sizeOf(vm.Cell));
    }

    pub fn storeC(self: @This(), value: u8) void {
        self.memory[self.offset] = value;
    }

    pub fn storeAddC(self: @This(), value: u8) void {
        self.memory[self.offset] +%= value;
    }

    pub fn fetchC(self: @This()) u8 {
        return self.memory[self.offset];
    }

    pub fn commaC(self: @This(), value: u8) void {
        self.memory[self.fetch()] = value;
        self.storeAdd(1);
    }

    pub fn alignForward(self: @This(), comptime Type: type) void {
        self.store(std.mem.alignForward(
            Type,
            self.fetch(),
            @alignOf(Type),
        ));
    }

    pub fn readByteAndAdvance(self: @This(), memory: []const u8) u8 {
        const addr = self.fetch();
        self.storeAdd(1);
        // TODO handle addr >= memory.len
        return memory[addr];
    }

    pub fn readCellAndAdvance(self: *@This(), memory: []const u8) vm.Cell {
        const low = self.readByteAndAdvance(memory);
        const high = self.readByteAndAdvance(memory);
        return @as(vm.Cell, high) << 8 | low;
    }
};

test "registers" {
    const testing = @import("std").testing;

    const memory = try vm.allocateMemory(testing.allocator);
    defer testing.allocator.free(memory);

    var reg_a: Register = undefined;
    var reg_b: Register = undefined;
    reg_a.init(memory, 0);
    reg_b.init(memory, 2);

    reg_a.store(0xdead);
    reg_b.store(0xbeef);
    try testing.expectEqualSlices(u8, &[_]u8{ 0xad, 0xde, 0xef, 0xbe }, memory[0..4]);

    reg_a.storeAdd(0x1111);
    reg_b.storeAdd(0x2222);
    try testing.expectEqualSlices(u8, &[_]u8{ 0xbe, 0xef, 0x11, 0xe1 }, memory[0..4]);

    try testing.expectEqual(0xefbe, reg_a.fetch());

    var here: Register = undefined;
    here.init(memory, 0);
    here.store(2);
    here.comma(0xadde);
    here.comma(0xefbe);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x06, 0x00, 0xde, 0xad, 0xbe, 0xef }, memory[0..6]);

    here.storeC(2);
    here.commaC(0xab);
    here.commaC(0xcd);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x04, 0x00, 0xab, 0xcd, 0xbe, 0xef }, memory[0..6]);

    try testing.expectEqual(0x04, here.fetchC());
    here.storeAddC(1);
    try testing.expectEqual(0x05, here.fetchC());
    here.alignForward(vm.Cell);
    try testing.expectEqual(0x06, here.fetchC());
}
