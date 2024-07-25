const std = @import("std");

const vm = @import("mini.zig");

// Error handling strategy:
// For the sake of not having the entire code base be full of 'try'
//   OutOfBounds errors are only thrown when _memory or _offset is changed
//     (or from functions that access arbitrary unrelated memory)
// There are no public functions that allow users to change _memory or _offset
//   so if they go in and modify them on thier own, that's thier problem

/// A register is basically a pointer into VM Memory
/// It's memory-mapped, rather than being a system pointer
///   so, an offset of 0 means memory[0]
pub const Register = struct {
    pub const Error = vm.OutOfBoundsError;

    // NOTE
    // If these two fields were instead a vm.Cell pointer,
    //   you wouldnt be able to have comma() readByteAndAdvance() etc
    _memory: vm.Memory,
    _offset: vm.Cell,

    pub fn init(self: *@This(), memory: vm.Memory, offset: vm.Cell) Error!void {
        if (offset >= memory.len) {
            return error.OutOfBounds;
        }
        self._memory = memory;
        self._offset = offset;
    }

    pub fn address(self: @This()) void {
        return self._offset;
    }

    pub fn store(self: @This(), value: vm.Cell) void {
        // TODO do we really need this to be byte aligned?
        vm.mem.writeByteAlignedCell(
            self._memory,
            self._offset,
            value,
        ) catch unreachable;
    }

    pub fn fetch(self: @This()) vm.Cell {
        // TODO do we really need this to be byte aligned?
        return vm.mem.readByteAlignedCell(
            self._memory,
            self._offset,
        ) catch unreachable;
    }

    pub fn storeAdd(self: @This(), to_add: vm.Cell) void {
        const value = self.fetch();
        self.store(value +% to_add);
    }

    pub fn storeSubtract(self: @This(), to_subtract: vm.Cell) void {
        const value = self.fetch();
        self.store(value -% to_subtract);
    }

    pub fn comma(self: @This(), value: vm.Cell) Error!void {
        // TODO do we really need this to be byte aligned?
        // i think this is the main reason for it
        try vm.mem.writeByteAlignedCell(self._memory, self.fetch(), value);
        self.storeAdd(@sizeOf(vm.Cell));
    }

    pub fn storeC(self: @This(), value: u8) void {
        const byte = vm.mem.checkedAccess(
            self._memory,
            self._offset,
        ) catch unreachable;
        byte.* = value;
    }

    pub fn fetchC(self: @This()) u8 {
        const byte = vm.mem.checkedRead(
            self._memory,
            self._offset,
        ) catch unreachable;
        return byte;
    }

    pub fn storeAddC(self: @This(), value: u8) void {
        const byte = vm.mem.checkedAccess(self._memory, self._offset) catch unreachable;
        byte.* +%= value;
    }

    pub fn commaC(self: @This(), value: u8) Error!void {
        const byte = try vm.mem.checkedAccess(self._memory, self.fetch());
        byte.* = value;
        self.storeAdd(1);
    }

    // TODO this can take alignment as a usize
    pub fn alignForward(self: @This(), comptime Type: type) void {
        self.store(std.mem.alignForward(
            Type,
            self.fetch(),
            @alignOf(Type),
        ));
    }

    pub fn readByteAndAdvance(self: @This(), memory: []const u8) Error!u8 {
        const addr = self.fetch();
        self.storeAdd(1);
        return try vm.mem.checkedRead(memory, addr);
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
    try reg_a.init(memory, 0);
    try reg_b.init(memory, 2);

    reg_a.store(0xdead);
    reg_b.store(0xbeef);
    try testing.expectEqualSlices(u8, &[_]u8{ 0xad, 0xde, 0xef, 0xbe }, memory[0..4]);

    reg_a.storeAdd(0x1111);
    reg_b.storeAdd(0x2222);
    try testing.expectEqualSlices(u8, &[_]u8{ 0xbe, 0xef, 0x11, 0xe1 }, memory[0..4]);

    try testing.expectEqual(0xefbe, reg_a.fetch());

    var here: Register = undefined;
    try here.init(memory, 0);
    here.store(2);
    try here.comma(0xadde);
    try here.comma(0xefbe);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x06, 0x00, 0xde, 0xad, 0xbe, 0xef }, memory[0..6]);

    here.storeC(2);
    try here.commaC(0xab);
    try here.commaC(0xcd);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x04, 0x00, 0xab, 0xcd, 0xbe, 0xef }, memory[0..6]);

    try testing.expectEqual(0x04, here.fetchC());
    here.storeAddC(1);
    try testing.expectEqual(0x05, here.fetchC());
    here.alignForward(vm.Cell);
    try testing.expectEqual(0x06, here.fetchC());
}
