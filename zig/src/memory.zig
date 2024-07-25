const std = @import("std");
const Allocator = std.mem.Allocator;

const vm = @import("mini.zig");

const WordHeader = @import("word_header.zig").WordHeader;

// Alignment strategy:
// Its slighty annoying to work with but cells should be cell aligned
//   rather than byte aligned
// The exception is for bytecodes like 'lit',
//   the data that follows may be byte aligned

pub const MemoryError = error{
    AlignmentError,
    OutOfBounds,
};

pub fn checkedAccess(memory: []u8, addr: usize) MemoryError!*u8 {
    if (addr >= memory.len) {
        return error.OutOfBounds;
    }

    return &memory[addr];
}

pub fn checkedRead(memory: []const u8, addr: usize) MemoryError!u8 {
    if (addr >= memory.len) {
        return error.OutOfBounds;
    }

    return memory[addr];
}

pub fn readByteAlignedCell(
    memory: []const u8,
    addr: usize,
) MemoryError!vm.Cell {
    const high_byte = try checkedRead(memory, addr + 1);
    const low_byte = try checkedRead(memory, addr);
    return (@as(vm.Cell, high_byte) << 8) | low_byte;
}

pub fn writeByteAlignedCell(
    memory: []u8,
    addr: usize,
    value: vm.Cell,
) MemoryError!void {
    const high_byte = try checkedAccess(memory, addr + 1);
    const low_byte = try checkedAccess(memory, addr);
    high_byte.* = @truncate(value >> 8);
    low_byte.* = @truncate(value);
}

pub fn cellAt(memory: []u8, addr: vm.Cell) MemoryError!*vm.Cell {
    if (addr >= memory.len) {
        return error.OutOfBounds;
    }
    // TODO alignment error
    return @ptrCast(@alignCast(&memory[addr]));
}

pub fn sliceAt(memory: []u8, addr: vm.Cell, len: vm.Cell) MemoryError![]vm.Cell {
    if (addr + len >= memory.len) {
        return error.OutOfBounds;
    }
    // TODO alignment error
    const ptr: [*]vm.Cell = @ptrCast(@alignCast(&memory[addr]));
    return ptr[0..len];
}

// TODO move this into the word headers file
pub fn calculateCfaAddress(memory: []u8, addr: vm.Cell) vm.Error!vm.Cell {
    // TODO alignment error ?
    var temp_word_header: WordHeader = undefined;
    try temp_word_header.initFromMemory(memory[addr..]);
    return addr + temp_word_header.size();
}

pub fn sliceFromAddrAndLen(memory: []u8, addr: usize, len: usize) MemoryError![]u8 {
    if (addr + len >= memory.len) {
        return error.OutOfBounds;
    }
    return memory[addr..][0..len];
}

// ===

pub const CellAlignedMemory = []align(@alignOf(vm.Cell)) u8;

pub fn allocateCellAlignedMemory(
    allocator: Allocator,
    size: usize,
) Allocator.Error!CellAlignedMemory {
    return try allocator.allocWithOptions(u8, size, @alignOf(vm.Cell), null);
}

// ===

test "memory" {
    // TODO
}
