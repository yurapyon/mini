const std = @import("std");
const Allocator = std.mem.Allocator;

const runtime = @import("runtime.zig");
const Cell = runtime.Cell;

pub const Error = error{
    MisalignedAddress,
    OutOfBounds,
};

// NOTE
// in bounds memory access is guaranteed because
//   the size of memory is defined in terms of the max address a cell can hold
pub const memory_size = std.math.maxInt(Cell) + 1;
pub const Memory = [memory_size]u8;
pub const MemoryPtr = *align(@alignOf(Cell)) Memory;
pub const ConstMemoryPtr = *align(@alignOf(Cell)) const Memory;

pub fn allocateMemory(allocator: Allocator) Allocator.Error!MemoryPtr {
    const slice = try allocator.allocWithOptions(
        u8,
        memory_size,
        @alignOf(Cell),
        null,
    );
    return @ptrCast(slice.ptr);
}

pub fn assertOffsetInBounds(addr: Cell, offset: Cell) Error!void {
    _ = std.math.add(Cell, addr, offset) catch {
        return error.OutOfBounds;
    };
}

pub fn assertCellAccess(addr: Cell) Error!void {
    if (addr % @alignOf(Cell) != 0) {
        return error.MisalignedAddress;
    }
}

pub fn readCell(memory: ConstMemoryPtr, addr: Cell) Error!Cell {
    try assertCellAccess(addr);
    const cell_ptr: *const Cell = @ptrCast(@alignCast(&memory[addr]));
    return cell_ptr.*;
}

pub fn cellPtr(memory: MemoryPtr, addr: Cell) Error!*Cell {
    try assertCellAccess(addr);
    return @ptrCast(@alignCast(&memory[addr]));
}

pub fn writeCell(memory: MemoryPtr, addr: Cell, value: Cell) Error!void {
    (try cellPtr(memory, addr)).* = value;
}

pub fn alignToCell(addr: Cell) Cell {
    return std.mem.alignForward(
        Cell,
        addr,
        @alignOf(Cell),
    );
}

pub fn sliceFromAddrAndLen(
    memory: []u8,
    addr: Cell,
    len: Cell,
) Error![]u8 {
    if (len > 0) {
        try assertOffsetInBounds(addr, len - 1);
    }
    return memory[addr..][0..len];
}

pub fn constSliceFromAddrAndLen(
    memory: []const u8,
    addr: Cell,
    len: Cell,
) Error![]const u8 {
    if (len > 0) {
        try assertOffsetInBounds(addr, len - 1);
    }
    return memory[addr..][0..len];
}
