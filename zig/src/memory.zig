const std = @import("std");
const Allocator = std.mem.Allocator;

const kernel = @import("kernel.zig");
const Cell = kernel.Cell;

// ===

// NOTE
// in bounds memory access is guaranteed because
//   the size of memory is defined in terms of the max address a cell can hold
pub const forth_memory_size = std.math.maxInt(Cell) + 1;
pub const Memory = [forth_memory_size]u8;
pub const MemoryPtr = *align(@alignOf(Cell)) Memory;
pub const ConstMemoryPtr = *align(@alignOf(Cell)) const Memory;

// Allocates Cell aligned memory
pub fn allocate(allocator: Allocator, size: usize) Allocator.Error![]u8 {
    const slice = try allocator.allocWithOptions(
        u8,
        size,
        std.mem.Alignment.fromByteUnits(@alignOf(Cell)),
        null,
    );
    return slice;
}

pub fn allocateForthMemory(allocator: Allocator) Allocator.Error!MemoryPtr {
    const slice = try allocate(allocator, forth_memory_size);
    return @ptrCast(@alignCast(slice.ptr));
}

pub fn assertOffsetInBounds(addr: Cell, offset: Cell) !void {
    _ = std.math.add(Cell, addr, offset) catch {
        return error.OutOfBounds;
    };
}

pub fn assertCellAccess(addr: Cell) !void {
    if (addr % @alignOf(Cell) != 0) {
        return error.MisalignedAddress;
    }
}

pub fn readCell(
    memory: ConstMemoryPtr,
    addr: Cell,
) !Cell {
    try assertCellAccess(addr);
    const cell_ptr: *const Cell = @ptrCast(@alignCast(&memory[addr]));
    return cell_ptr.*;
}

pub fn cellPtr(memory: MemoryPtr, addr: Cell) !*Cell {
    try assertCellAccess(addr);
    return @ptrCast(@alignCast(&memory[addr]));
}

pub fn writeCell(
    memory: MemoryPtr,
    addr: Cell,
    value: Cell,
) !void {
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
) ![]u8 {
    if (len > 0) {
        try assertOffsetInBounds(addr, len - 1);
    }
    return memory[addr..][0..len];
}

pub fn constSliceFromAddrAndLen(
    memory: []const u8,
    addr: Cell,
    len: Cell,
) ![]const u8 {
    if (len > 0) {
        try assertOffsetInBounds(addr, len - 1);
    }
    return memory[addr..][0..len];
}
