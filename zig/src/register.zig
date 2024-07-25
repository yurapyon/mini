const std = @import("std");

const vm = @import("mini.zig");
const memory = @import("memory.zig");

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
    _memory: []u8,
    _offset: vm.Cell,

    pub fn init(
        self: *@This(),
        mem: []u8,
        offset: vm.Cell,
    ) Error!void {
        if (offset >= mem.len) {
            return error.OutOfBounds;
        }
        self._memory = mem;
        self._offset = offset;
    }

    pub fn address(self: @This()) void {
        return self._offset;
    }

    pub fn store(self: *@This(), value: vm.Cell) void {
        self._memory.writeByteAlignedCell(self._offset, value) catch unreachable;
    }

    pub fn storeAdd(self: *@This(), to_add: vm.Cell) void {
        const value = self._memory.readByteAlignedCell(
            self._offset,
        ) catch unreachable;
        self._memory.writeByteAlignedCell(
            self._offset,
            value +% to_add,
        ) catch unreachable;
    }

    pub fn storeSubtract(self: *@This(), to_subtract: vm.Cell) void {
        const value = self._memory.readByteAlignedCell(
            self._offset,
        ) catch unreachable;
        self._memory.writeByteAlignedCell(
            self._offset,
            value -% to_subtract,
        ) catch unreachable;
    }

    pub fn fetch(self: @This()) vm.Cell {
        return self._memory.readByteAlignedCell(self._offset) catch unreachable;
    }

    pub fn comma(self: *@This(), value: vm.Cell) Error!void {
        try self._memory.writeByteAlignedCell(self.fetch(), value);
        self.storeAdd(@sizeOf(vm.Cell));
    }

    pub fn storeC(self: *@This(), value: u8) void {
        const byte = memory.checkedAccess(self._memory.data, self._offset) catch unreachable;
        byte.* = value;
    }

    pub fn storeAddC(self: *@This(), value: u8) void {
        const byte = memory.checkedAccess(self._memory.data, self._offset) catch unreachable;
        byte.* +%= value;
    }

    pub fn fetchC(self: @This()) u8 {
        const byte = memory.checkedAccess(self._memory.data, self._offset) catch unreachable;
        return byte.*;
    }

    pub fn commaC(self: *@This(), value: u8) Error!void {
        const byte = try memory.checkedAccess(self._memory.data, self.fetch());
        byte.* = value;
        self.storeAdd(1);
    }

    // TODO this can take alignment as a usize
    pub fn alignForward(self: *@This(), comptime Type: type) void {
        self.store(std.mem.alignForward(
            Type,
            self.fetch(),
            @alignOf(Type),
        ));
    }

    pub fn readByteAndAdvance(self: @This(), other_memory: []const u8) Error!u8 {
        const addr = self.fetch();
        self.storeAdd(1);
        return try memory.checkedRead(other_memory, addr);
    }

    pub fn readCellAndAdvance(self: *@This(), other_memory: []const u8) Error!vm.Cell {
        const low = try self.readByteAndAdvance(other_memory);
        const high = try self.readByteAndAdvance(other_memory);
        return @as(vm.Cell, high) << 8 | low;
    }
};

test "registers" {
    const testing = @import("std").testing;

    var m: memory.CellAlignedMemory = undefined;
    try m.init(testing.allocator);
    defer m.deinit();

    var reg_a: Register = undefined;
    var reg_b: Register = undefined;
    try reg_a.init(m, 0);
    try reg_b.init(m, 2);

    reg_a.store(0xdead);
    reg_b.store(0xbeef);
    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 0xad, 0xde, 0xef, 0xbe },
        m.data[0..4],
    );

    reg_a.storeAdd(0x1111);
    reg_b.storeAdd(0x2222);
    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 0xbe, 0xef, 0x11, 0xe1 },
        m.data[0..4],
    );

    try testing.expectEqual(0xefbe, reg_a.fetch());

    var here: Register = undefined;
    try here.init(m, 0);
    here.store(2);
    try here.comma(0xadde);
    try here.comma(0xefbe);
    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 0x06, 0x00, 0xde, 0xad, 0xbe, 0xef },
        m.data[0..6],
    );

    here.storeC(2);
    try here.commaC(0xab);
    try here.commaC(0xcd);
    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 0x04, 0x00, 0xab, 0xcd, 0xbe, 0xef },
        m.data[0..6],
    );

    try testing.expectEqual(0x04, here.fetchC());
    here.storeAddC(1);
    try testing.expectEqual(0x05, here.fetchC());
    here.alignForward(vm.Cell);
    try testing.expectEqual(0x06, here.fetchC());
}
