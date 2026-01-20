const std = @import("std");

const mem = @import("memory.zig");
const MemoryPtr = mem.MemoryPtr;

const kernel = @import("kernel.zig");
const Cell = kernel.Cell;

// ===

// NOTE
// reasoning to use this over a normal *Cell:
//   by using a cell sized offset, we get
//     - memory mapping
//     - defining the location at comptime
//       - verify alignment and in-bounds access in most cases
//     - quick and easy pointer arithmetic outside of zig's ptr type constraints
//   a raw pointer is more "natural" but the tradeoffs are probably worth it

/// A register is basically a pointer into VM Memory
pub fn Register(comptime offset_: Cell) type {
    return struct {
        comptime {
            mem.assertCellAccess(offset_) catch {
                @compileError("Register must be Cell aligned");
            };
        }

        pub const offset = offset_;

        memory: MemoryPtr,

        pub fn init(self: *@This(), memory: MemoryPtr) void {
            self.memory = memory;
        }

        pub fn store(self: @This(), value: Cell) void {
            mem.writeCell(self.memory, offset, value) catch unreachable;
        }

        pub fn fetch(self: @This()) Cell {
            return mem.readCell(self.memory, offset) catch unreachable;
        }

        pub fn storeAdd(self: @This(), value: Cell) void {
            const cell_ptr = mem.cellPtr(self.memory, offset) catch unreachable;
            cell_ptr.* +%= value;
        }

        pub fn storeSubtract(self: @This(), value: Cell) void {
            const cell_ptr = mem.cellPtr(self.memory, offset) catch unreachable;
            cell_ptr.* -%= value;
        }
    };
}
