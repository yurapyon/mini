const std = @import("std");

const vm = @import("mini.zig");

const Range = @import("range.zig");

/// A register is basically a pointer into VM Memory
/// Won't crash as long as offset is within memory
///   This is checked for on init
pub fn Register(comptime offset_: vm.Cell) type {
    return struct {
        comptime {
            if (offset % @alignOf(vm.Cell) != 0) {
                @compileError("Register must be vm.Cell aligned");
            }
        }

        pub const offset = offset_;

        memory: vm.mem.CellAlignedMemory,

        pub fn init(
            self: *@This(),
            memory: vm.mem.CellAlignedMemory,
        ) vm.mem.MemoryError!void {
            if (offset >= memory.len) {
                return error.OutOfBounds;
            }
            self.memory = memory;
        }

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

        pub fn deref(
            self: @This(),
            memory: vm.mem.CellAlignedMemory,
        ) vm.mem.MemoryError!vm.Cell {
            return (try vm.mem.cellAt(memory, self.fetch())).*;
        }

        /// Will error if self.fetch() is not cell aligned and within write_to
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
        ) vm.Cell {
            const new_addr = std.mem.alignForward(
                vm.Cell,
                self.fetch(),
                alignment,
            );
            self.store(new_addr);
            return new_addr;
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

        /// Will error if self.fetch() is not within write_to
        pub fn commaC(
            self: @This(),
            write_to: []u8,
            value: u8,
        ) vm.mem.MemoryError!void {
            const byte = try vm.mem.checkedAccess(write_to, self.fetch());
            byte.* = value;
            self.storeAdd(1);
        }

        /// Will error if self.fetch() is not within write_to
        pub fn commaByteAlignedCell(
            self: @This(),
            write_to: []u8,
            value: vm.Cell,
        ) vm.mem.MemoryError!void {
            try vm.mem.writeByteAlignedCell(write_to, self.fetch(), value);
            self.storeAdd(@sizeOf(vm.Cell));
        }

        // TODO rename to derefByte & derefCell

        /// Will error if self.fetch() is not within read_from
        pub fn readByteAndAdvance(
            self: @This(),
            read_from: []const u8,
        ) vm.mem.MemoryError!u8 {
            const addr = self.fetch();
            self.storeAdd(1);
            return try vm.mem.checkedRead(read_from, addr);
        }

        /// Will error if self.fetch()+1 is not within read_from
        pub fn readCellAndAdvance(
            self: @This(),
            read_from: []const u8,
        ) vm.mem.MemoryError!vm.Cell {
            const low = try self.readByteAndAdvance(read_from);
            const high = try self.readByteAndAdvance(read_from);
            return @as(vm.Cell, high) << 8 | low;
        }

        /// Will error if self.fetch()+string.len is not within read_from
        pub fn commaString(
            self: @This(),
            string: []const u8,
        ) vm.Error!void {
            if (string.len > std.math.maxInt(vm.Cell)) {
                // TODO rename this to StringTooLong or something
                return error.WordNameTooLong;
            }
            const dest = try vm.mem.sliceFromAddrAndLen(
                self.memory,
                self.fetch(),
                string.len,
            );
            @memcpy(dest, string);
            self.storeAdd(@intCast(string.len));
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
    const aligned_here = here.alignForward(@alignOf(vm.Cell));
    try testing.expectEqual(0x06, here.fetchC());
    try testing.expectEqual(0x06, aligned_here);

    here.store(2);
    try here.comma(memory, 0xbeef);
    here.storeSubtract(2);
    try testing.expectEqual(0xbeef, try here.deref(memory));
}
