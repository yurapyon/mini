const std = @import("std");

const mem = @import("memory.zig");
const runtime = @import("runtime.zig");
const Cell = runtime.Cell;

pub const Error = error{
    OutOfBounds,
};

/// A register is basically a pointer into VM Memory
pub fn Register(comptime offset: Cell) type {
    return struct {
        comptime {
            mem.assertCellAccess(offset) catch {
                @compileError("Register must be Cell aligned");
            };
        }

        memory: mem.MemoryPtr,

        pub fn init(self: *@This(), memory: mem.MemoryPtr) void {
            self.memory = memory;
        }

        fn assertForwardReference(self: @This(), deref_offset: Cell) Error!void {
            const addr = self.fetch();
            if (addr + deref_offset >= mem.memory_size) {
                return error.OutOfBounds;
            }
        }

        // Cells ===

        pub fn store(self: @This(), value: Cell) void {
            mem.writeCell(self.memory, offset, value) catch unreachable;
        }

        //         pub fn storeWithOffset(
        //             self: @This(),
        //             addr_offset: Cell,
        //             value: Cell,
        //         ) mem.Error!void {
        //             try mem.writeCell(self.memory, offset +% addr_offset, value);
        //         }

        pub fn fetch(self: @This()) Cell {
            return mem.readCell(self.memory, offset) catch unreachable;
        }

        //         pub fn fetchWithOffset(self: @This(), addr_offset: Cell) mem.Error!Cell {
        //             return try mem.readCell(self.memory, offset +% addr_offset);
        //         }

        pub fn storeAdd(self: @This(), value: Cell) void {
            const cell_ptr = mem.cellPtr(self.memory, offset) catch unreachable;
            cell_ptr.* +%= value;
        }

        pub fn storeSubtract(self: @This(), value: Cell) void {
            const cell_ptr = mem.cellPtr(self.memory, offset) catch unreachable;
            cell_ptr.* -%= value;
        }

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

        pub fn derefAndAdvance(self: @This()) Error!Cell {
            const low = try self.derefAndAdvanceC();
            const high = try self.derefAndAdvanceC();
            return @as(Cell, high) << 8 | low;
        }

        // TODO
        //         /// Will error if self.fetch() is not within write_to
        //         pub fn commaByteAlignedCell(
        //             self: @This(),
        //             value: Cell
        //         ) mem.MemoryError!void {
        //             try mem.writeByteAlignedCell(write_to, self.fetch(), value);
        //             self.storeAdd(@sizeOf(Cell));
        //         }

        // u8s ===

        pub fn storeC(self: @This(), value: u8) void {
            self.memory[offset] = value;
        }

        pub fn fetchC(self: @This()) u8 {
            return self.memory[offset];
        }

        pub fn storeAddC(self: @This(), value: u8) void {
            self.memory[offset] += value;
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

        // TODO
        //         pub fn commaString(self: @This(), string: []const u8) Error!void {
        //             if (string.len > std.math.maxInt(Cell)) {
        //                 return error.OutOfBounds;
        //             }
        //             const dest = try mem.sliceFromAddrAndLen(
        //                 self.memory,
        //                 self.fetch(),
        //                 string.len,
        //             );
        //             @memcpy(dest, string);
        //             self.storeAdd(@intCast(string.len));
        //         }
    };
}

test "registers" {
    const testing = @import("std").testing;

    const memory = try mem.allocateMemory(testing.allocator);
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
    const aligned_here = here.alignForward();
    try testing.expectEqual(0x06, here.fetchC());
    try testing.expectEqual(0x06, aligned_here);

    here.store(2);
    try here.comma(0xbeef);
    // here.storeSubtract(2);
    // try testing.expectEqual(0xbeef, try here.deref(memory));

    // TODO more tests
}
