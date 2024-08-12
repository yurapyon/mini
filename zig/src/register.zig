const std = @import("std");

const mem = @import("memory.zig");
const MemoryPtr = mem.MemoryPtr;

const runtime = @import("runtime.zig");
const Cell = runtime.Cell;

pub const Error = error{
    OutOfBounds,
    StringTooLong,
};

// NOTE
// reasoning to use this over a normal *Cell:
//   by using a cell sized offset, we get
//     - memory mapping
//     - defining the location at comptime
//       - verify alignment and in-bounds access in most cases
//     - quick and easy pointer arithmetic outside of zig's ptr type constraints
//   also, the offset is more easily passed to forth, which is very common
//     i.e. for 'here' and 'latest'
//   a raw pointer is more "natural" but i think the tradeoffs are worth it

/// A register is basically a pointer into VM Memory
pub fn Register(comptime offset: Cell) type {
    return struct {
        comptime {
            mem.assertCellAccess(offset) catch {
                @compileError("Register must be Cell aligned");
            };
        }

        memory: MemoryPtr,

        pub fn init(self: *@This(), memory: MemoryPtr) void {
            self.memory = memory;
        }

        fn assertForwardOffset(address_offset: Cell) Error!void {
            _ = std.math.add(Cell, offset, address_offset) catch {
                return error.OutOfBounds;
            };
        }

        fn assertForwardReference(self: @This(), reference_offset: Cell) Error!void {
            const addr = self.fetch();
            _ = std.math.add(Cell, addr, reference_offset) catch {
                return error.OutOfBounds;
            };
        }

        // Cells ===

        pub fn store(self: @This(), value: Cell) void {
            mem.writeCell(self.memory, offset, value) catch unreachable;
        }

        pub fn storeWithOffset(
            self: @This(),
            addr_offset: Cell,
            value: Cell,
        ) (Error || mem.Error)!void {
            try assertForwardOffset(addr_offset);
            try mem.writeCell(self.memory, offset + addr_offset, value);
        }

        pub fn fetch(self: @This()) Cell {
            return mem.readCell(self.memory, offset) catch unreachable;
        }

        pub fn fetchWithOffset(
            self: @This(),
            addr_offset: Cell,
        ) (Error || mem.Error)!Cell {
            try assertForwardOffset(addr_offset);
            return try mem.readCell(self.memory, offset + addr_offset);
        }

        pub fn storeAdd(self: @This(), value: Cell) void {
            const cell_ptr = mem.cellPtr(self.memory, offset) catch unreachable;
            cell_ptr.* +%= value;
        }

        pub fn storeSubtract(self: @This(), value: Cell) void {
            const cell_ptr = mem.cellPtr(self.memory, offset) catch unreachable;
            cell_ptr.* -%= value;
        }

        // TODO
        //         pub fn deref(
        //             self: @This(),
        //         ) mem.MemoryError!Cell {
        //             return (try mem.cellAt(memory, self.fetch())).*;
        //         }

        pub fn comma(self: @This(), value: Cell) (Error || mem.Error)!void {
            try self.assertForwardReference(@sizeOf(Cell));
            const addr = self.fetch();
            try mem.writeCell(self.memory, addr, value);
            self.storeAdd(@sizeOf(Cell));
        }

        pub fn alignForward(self: @This()) Cell {
            const new_addr = mem.alignToCell(self.fetch());
            self.store(new_addr);
            return new_addr;
        }

        pub fn derefByteAlignedAndAdvance(self: @This()) Error!Cell {
            const low = try self.derefAndAdvanceC();
            const high = try self.derefAndAdvanceC();
            return @as(Cell, high) << 8 | low;
        }

        pub fn commaByteAligned(self: @This(), value: Cell) Error!void {
            const high: u8 = @truncate(value >> 8);
            const low: u8 = @truncate(value);
            try self.commaC(low);
            try self.commaC(high);
        }

        // u8s ===

        pub fn storeC(self: @This(), value: u8) void {
            self.memory[offset] = value;
        }

        pub fn fetchC(self: @This()) u8 {
            return self.memory[offset];
        }

        pub fn storeAddC(self: @This(), value: u8) void {
            self.memory[offset] +%= value;
        }

        pub fn commaC(self: @This(), value: u8) Error!void {
            try self.assertForwardReference(1);
            const addr = self.fetch();
            self.memory[addr] = value;
            self.storeAdd(1);
        }

        pub fn derefAndAdvanceC(self: @This()) Error!u8 {
            try self.assertForwardReference(1);
            const addr = self.fetch();
            self.storeAdd(1);
            return self.memory[addr];
        }

        // ===

        pub fn commaString(self: @This(), string: []const u8) (Error || mem.Error)!void {
            if (string.len > std.math.maxInt(Cell)) {
                return error.StringTooLong;
            }

            const cell_str_len: Cell = @intCast(string.len);
            try self.assertForwardReference(cell_str_len);
            const dest = try mem.sliceFromAddrAndLen(
                self.memory,
                self.fetch(),
                cell_str_len,
            );
            @memcpy(dest, string);
            self.storeAdd(@intCast(string.len));
        }
    };
}

test "register: store fetch" {
    const testing = @import("std").testing;

    const memory = try mem.allocateMemory(testing.allocator);
    defer testing.allocator.free(memory);

    const a_loc = 0;
    const b_loc = 2;

    var reg_a: Register(a_loc) = undefined;
    var reg_b: Register(b_loc) = undefined;

    reg_a.init(memory);
    reg_b.init(memory);

    reg_a.store(0xdead);
    reg_b.store(0xbeef);
    try expectMemory(
        memory,
        &[_]u8{ 0xad, 0xde, 0xef, 0xbe },
    );

    reg_a.storeAdd(0x1111);
    reg_b.storeAdd(0x2222);
    try expectMemory(
        memory,
        &[_]u8{ 0xbe, 0xef, 0x11, 0xe1 },
    );

    try testing.expectEqual(0xefbe, reg_a.fetch());

    reg_a.storeSubtract(0x1111);
    reg_b.storeSubtract(0x2222);
    try expectMemory(
        memory,
        &[_]u8{ 0xad, 0xde, 0xef, 0xbe },
    );

    try reg_a.storeWithOffset(2, 0xbeef);
    try testing.expectEqual(0xbeef, try reg_a.fetchWithOffset(2));
    try testing.expectEqual(0xbeef, reg_b.fetch());

    try testing.expectEqual(error.MisalignedAddress, reg_a.fetchWithOffset(1));
    try testing.expectEqual(error.OutOfBounds, reg_b.fetchWithOffset(0xfffe));
}

test "register: comma" {
    const testing = @import("std").testing;

    const memory = try mem.allocateMemory(testing.allocator);
    defer testing.allocator.free(memory);

    const here_loc = 0;
    var here: Register(here_loc) = undefined;
    here.init(memory);

    here.store(2);
    try here.comma(0xadde);
    try here.comma(0xefbe);
    try expectMemory(
        memory,
        &[_]u8{ 0x06, 0x00, 0xde, 0xad, 0xbe, 0xef },
    );

    here.store(0xffff);
    try testing.expectEqual(error.OutOfBounds, here.comma(0xbeef));
    here.store(0x0001);
    try testing.expectEqual(error.MisalignedAddress, here.comma(0xbeef));
    try testing.expectEqual(2, here.alignForward());
    try testing.expectEqual(2, here.fetch());

    here.storeC(2);
    try here.commaC(0xab);
    try here.commaC(0xcd);
    try expectMemory(
        memory,
        &[_]u8{ 0x04, 0x00, 0xab, 0xcd, 0xbe, 0xef },
    );

    here.store(3);
    try testing.expectEqual(0xbecd, try here.derefByteAlignedAndAdvance());
    here.store(3);
    try here.commaByteAligned(0x1234);
    here.store(3);
    try testing.expectEqual(0x1234, try here.derefByteAlignedAndAdvance());
}

fn expectMemory(memory: MemoryPtr, expectation: []const u8) !void {
    const testing = @import("std").testing;
    try testing.expectEqualSlices(
        u8,
        expectation,
        memory[0..expectation.len],
    );
}
