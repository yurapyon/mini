const std = @import("std");

const vm = @import("mini.zig");

fn checkedAccess(memory: []u8, addr: usize) vm.OutOfBoundsError!*u8 {
    if (addr >= memory.len) {
        return error.OutOfBounds;
    }

    return &memory[addr];
}

/// A register is basically a pointer into VM Memory
/// It's memory-mapped, rather than being a system pointer
///   so, an offset of 0 means memory[0]
pub const Register = struct {
    pub const Error = vm.OutOfBoundsError;

    // NOTE
    // If these two fields were instead a vm.Cell pointer,
    //   you wouldnt be able to have comma() readByteAndAdvance() etc
    memory: vm.Memory,
    offset: vm.Cell,

    pub fn init(self: *@This(), memory: vm.Memory, offset: vm.Cell) void {
        self.memory = memory;
        self.offset = offset;
    }

    pub fn address(self: @This()) void {
        return self.offset;
    }

    // NOTE
    //   we have to be able to access vm.Cells with byte alignment
    //   so a function like below doesnt work
    // fn accessCell(self: @This(), addr: usize) *vm.Cell {
    //    return @ptrCast(@alignCast(&self.memory[addr]));
    // }

    // TODO try and refactor considering the above note
    fn readCell(self: @This(), addr: usize) Error!vm.Cell {
        const high_byte = try checkedAccess(self.memory, addr + 1);
        const low_byte = try checkedAccess(self.memory, addr);
        return (@as(vm.Cell, high_byte.*) << 8) | low_byte.*;
    }

    // TODO try and refactor considering the above note
    fn writeCell(self: @This(), addr: usize, value: vm.Cell) Error!void {
        const high_byte = try checkedAccess(self.memory, addr + 1);
        const low_byte = try checkedAccess(self.memory, addr);
        high_byte.* = @truncate(value >> 8);
        low_byte.* = @truncate(value);
    }

    pub fn store(self: @This(), value: vm.Cell) Error!void {
        try self.writeCell(self.offset, value);
    }

    pub fn storeAdd(self: @This(), to_add: vm.Cell) Error!void {
        const value = try self.readCell(self.offset);
        try self.writeCell(self.offset, value +% to_add);
    }

    pub fn storeSubtract(self: @This(), to_subtract: vm.Cell) Error!void {
        const value = try self.readCell(self.offset);
        try self.writeCell(self.offset, value -% to_subtract);
    }

    pub fn fetch(self: @This()) Error!vm.Cell {
        return try self.readCell(self.offset);
    }

    pub fn comma(self: @This(), value: vm.Cell) Error!void {
        try self.writeCell(try self.fetch(), value);
        try self.storeAdd(@sizeOf(vm.Cell));
    }

    pub fn storeC(self: @This(), value: u8) Error!void {
        const byte = try checkedAccess(self.memory, self.offset);
        byte.* = value;
    }

    pub fn storeAddC(self: @This(), value: u8) Error!void {
        const byte = try checkedAccess(self.memory, self.offset);
        byte.* +%= value;
    }

    pub fn fetchC(self: @This()) Error!u8 {
        const byte = try checkedAccess(self.memory, self.offset);
        return byte.*;
    }

    pub fn commaC(self: @This(), value: u8) Error!void {
        const byte = try checkedAccess(self.memory, try self.fetch());
        byte.* = value;
        try self.storeAdd(1);
    }

    // TODO this can take alignment as a usize
    pub fn alignForward(self: @This(), comptime Type: type) Error!void {
        try self.store(std.mem.alignForward(
            Type,
            try self.fetch(),
            @alignOf(Type),
        ));
    }

    pub fn readByteAndAdvance(self: @This(), memory: []const u8) Error!u8 {
        const addr = try self.fetch();
        try self.storeAdd(1);
        return try checkedAccess(memory, addr);
    }

    pub fn readCellAndAdvance(self: *@This(), memory: []const u8) Error!vm.Cell {
        const low = try self.readByteAndAdvance(memory);
        const high = try self.readByteAndAdvance(memory);
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

    try reg_a.store(0xdead);
    try reg_b.store(0xbeef);
    try testing.expectEqualSlices(u8, &[_]u8{ 0xad, 0xde, 0xef, 0xbe }, memory[0..4]);

    try reg_a.storeAdd(0x1111);
    try reg_b.storeAdd(0x2222);
    try testing.expectEqualSlices(u8, &[_]u8{ 0xbe, 0xef, 0x11, 0xe1 }, memory[0..4]);

    try testing.expectEqual(0xefbe, try reg_a.fetch());

    var here: Register = undefined;
    here.init(memory, 0);
    try here.store(2);
    try here.comma(0xadde);
    try here.comma(0xefbe);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x06, 0x00, 0xde, 0xad, 0xbe, 0xef }, memory[0..6]);

    try here.storeC(2);
    try here.commaC(0xab);
    try here.commaC(0xcd);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x04, 0x00, 0xab, 0xcd, 0xbe, 0xef }, memory[0..6]);

    try testing.expectEqual(0x04, try here.fetchC());
    try here.storeAddC(1);
    try testing.expectEqual(0x05, try here.fetchC());
    try here.alignForward(vm.Cell);
    try testing.expectEqual(0x06, try here.fetchC());
}
