const std = @import("std");
const Allocator = std.mem.Allocator;

const runtime = @import("runtime.zig");
const Cell = runtime.Cell;

// ===

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

pub fn assertOffsetInBounds(addr: Cell, offset: Cell) error{OutOfBounds}!void {
    _ = std.math.add(Cell, addr, offset) catch {
        return error.OutOfBounds;
    };
}

pub fn assertCellAccess(addr: Cell) error{MisalignedAddress}!void {
    if (addr % @alignOf(Cell) != 0) {
        return error.MisalignedAddress;
    }
}

pub fn readCell(
    memory: ConstMemoryPtr,
    addr: Cell,
) error{MisalignedAddress}!Cell {
    try assertCellAccess(addr);
    const cell_ptr: *const Cell = @ptrCast(@alignCast(&memory[addr]));
    return cell_ptr.*;
}

pub fn cellPtr(memory: MemoryPtr, addr: Cell) error{MisalignedAddress}!*Cell {
    try assertCellAccess(addr);
    return @ptrCast(@alignCast(&memory[addr]));
}

pub fn writeCell(
    memory: MemoryPtr,
    addr: Cell,
    value: Cell,
) error{MisalignedAddress}!void {
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
) error{OutOfBounds}![]u8 {
    if (len > 0) {
        try assertOffsetInBounds(addr, len - 1);
    }
    return memory[addr..][0..len];
}

pub fn constSliceFromAddrAndLen(
    memory: []const u8,
    addr: Cell,
    len: Cell,
) error{OutOfBounds}![]const u8 {
    if (len > 0) {
        try assertOffsetInBounds(addr, len - 1);
    }
    return memory[addr..][0..len];
}
