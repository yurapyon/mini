const std = @import("std");

const vm = @import("mini.zig");

const Range = @import("range.zig");

/// A register is basically a pointer into VM Memory
/// The memory the register is stored in is passed in for all functions
/// Won't crash as long as offset is within memory
pub fn Register(comptime offset_: vm.Cell) type {
    return struct {
        comptime {
            if (offset % @alignOf(vm.Cell) != 0) {
                @compileError("Register must be vm.Cell aligned");
            }
        }

        pub const offset = offset_;

        memory: vm.mem.CellAlignedMemory,

        pub fn store(
            self: @This(),
            value: vm.Cell,
        ) void {
            (vm.mem.cellAt(self.memory, offset) catch unreachable).* = value;
        }

        pub fn fetch(
            self: @This(),
        ) vm.Cell {
            return (vm.mem.cellAt(self.memory, offset) catch unreachable).*;
        }

        pub fn storeAdd(
            self: @This(),
            value: vm.Cell,
        ) void {
            (vm.mem.cellAt(self.memory, offset) catch unreachable).* +%= value;
        }

        pub fn storeSubtract(
            self: @This(),
            value: vm.Cell,
        ) void {
            (vm.mem.cellAt(self.memory, offset) catch unreachable).* -%= value;
        }

        /// May error if self.fetch() is not cell aligned and within write_to
        pub fn comma(
            self: @This(),
            write_to: vm.mem.CellAlignedMemory,
            value: vm.Cell,
        ) vm.mem.MemoryError!void {
            (try vm.mem.cellAt(write_to, self.fetch())).* = value;
            self.storeAdd(@sizeOf(vm.Cell));
        }

        pub fn alignForward(
            self: @This(),
            alignment: vm.Cell,
        ) void {
            self.store(std.mem.alignForward(
                vm.Cell,
                self.fetch(),
                alignment,
            ));
        }

        pub fn storeC(self: @This(), value: u8) void {
            const byte = vm.mem.checkedAccess(
                self.memory,
                offset,
            ) catch unreachable;
            byte.* = value;
        }

        pub fn fetchC(self: @This()) u8 {
            const byte = vm.mem.checkedRead(
                self.memory,
                offset,
            ) catch unreachable;
            return byte;
        }

        pub fn storeAddC(self: @This(), value: u8) void {
            const byte = vm.mem.checkedAccess(self.memory, offset) catch unreachable;
            byte.* +%= value;
        }

        /// May error if self.fetch() is not within write_to
        pub fn commaC(
            self: @This(),
            write_to: []u8,
            value: u8,
        ) vm.mem.MemoryError!void {
            const byte = try vm.mem.checkedAccess(write_to, self.fetch());
            byte.* = value;
            self.storeAdd(1);
        }

        /// May error if self.fetch() is not within read_from
        pub fn readByteAndAdvance(
            self: @This(),
            read_from: []const u8,
        ) vm.mem.MemoryError!u8 {
            const addr = self.fetch();
            self.storeAdd(1);
            return try vm.mem.checkedRead(read_from, addr);
        }

        /// May error if self.fetch()+1 is not within read_from
        pub fn readCellAndAdvance(
            self: @This(),
            read_from: []const u8,
        ) vm.mem.MemoryError!vm.Cell {
            const low = try self.readByteAndAdvance(read_from);
            const high = try self.readByteAndAdvance(read_from);
            return @as(vm.Cell, high) << 8 | low;
        }
    };
}

test "registers" {
    const testing = @import("std").testing;

    const memory = try vm.mem.allocateCellAlignedMemory(
        testing.allocator,
        vm.max_memory_size,
    );
    defer testing.allocator.free(memory);

    const reg_a = Register(0){ .memory = memory };
    const reg_b = Register(2){ .memory = memory };

    reg_a.store(0xdead);
    reg_b.store(0xbeef);
    try testing.expectEqualSlices(u8, &[_]u8{ 0xad, 0xde, 0xef, 0xbe }, memory[0..4]);

    reg_a.storeAdd(0x1111);
    reg_b.storeAdd(0x2222);
    try testing.expectEqualSlices(u8, &[_]u8{ 0xbe, 0xef, 0x11, 0xe1 }, memory[0..4]);

    try testing.expectEqual(0xefbe, reg_a.fetch());

    const here = Register(0){
        .memory = memory,
    };
    here.store(2);
    try here.comma(memory, 0xadde);
    try here.comma(memory, 0xefbe);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x06, 0x00, 0xde, 0xad, 0xbe, 0xef }, memory[0..6]);

    here.storeC(2);
    try here.commaC(memory, 0xab);
    try here.commaC(memory, 0xcd);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x04, 0x00, 0xab, 0xcd, 0xbe, 0xef }, memory[0..6]);

    try testing.expectEqual(0x04, here.fetchC());
    here.storeAddC(1);
    try testing.expectEqual(0x05, here.fetchC());
    here.alignForward(@alignOf(vm.Cell));
    try testing.expectEqual(0x06, here.fetchC());
}
