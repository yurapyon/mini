const std = @import("std");
const Allocator = std.mem.Allocator;

const vm = @import("mini.zig");

// Alignment strategy:
// Its slighty annoying to work with but cells should be cell aligned
//   rather than byte aligned
// The exception is for bytecodes like 'lit',
//   the data that follows may be byte aligned

// TODO can probably rename this to Error
pub const MemoryError = error{
    MisalignedAddress,
    OutOfBounds,
};

pub fn assertMemoryAccess(memory: []const u8, addr: usize) MemoryError!void {
    if (addr >= memory.len) {
        return error.OutOfBounds;
    }
}

pub fn assertCellMemoryAccess(memory: []const u8, addr: usize) MemoryError!void {
    if (!std.mem.isAligned(addr, @alignOf(vm.Cell))) {
        return error.MisalignedAddress;
    }
    try assertMemoryAccess(memory, addr + 1);
}

// TODO maybe rename this byteAt
pub fn checkedAccess(memory: []u8, addr: usize) MemoryError!*u8 {
    try assertMemoryAccess(memory, addr);
    return &memory[addr];
}

// TODO maybe rename this byteAtConst
pub fn checkedRead(memory: []const u8, addr: usize) MemoryError!u8 {
    try assertMemoryAccess(memory, addr);
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
    try assertCellMemoryAccess(memory, addr);
    return @ptrCast(@alignCast(&memory[addr]));
}

// TODO this and the next function have pretty similar names
pub fn sliceAt(memory: []u8, addr: vm.Cell, len: vm.Cell) MemoryError![]vm.Cell {
    const last_addr = addr + len - 1;
    try assertCellMemoryAccess(memory, last_addr);
    const ptr: [*]vm.Cell = @ptrCast(@alignCast(&memory[addr]));
    return ptr[0..len];
}

pub fn sliceFromAddrAndLen(memory: []u8, addr: usize, len: usize) MemoryError![]u8 {
    const last_addr = addr + len - 1;
    try assertMemoryAccess(memory, last_addr);
    return memory[addr..][0..len];
}

pub fn constSliceFromAddrAndLen(memory: []const u8, addr: usize, len: usize) MemoryError![]const u8 {
    const last_addr = addr + len - 1;
    try assertMemoryAccess(memory, last_addr);
    return memory[addr..][0..len];
}

// ===

// NOTE
// It would be nice to just use []vm.Cell's everywhere, rather than this funny type.
//   As long as u16 arrays are contiguous in memory that would technically be fine.
// I think though that just specifying the alignment puts less constraints on the type?
// Memory is more often used as a []u8

pub const CellAlignedMemory = []align(@alignOf(vm.Cell)) u8;

pub fn allocateCellAlignedMemory(
    allocator: Allocator,
    size: usize,
) Allocator.Error!CellAlignedMemory {
    return try allocator.allocWithOptions(u8, size, @alignOf(vm.Cell), null);
}

// ===

test "memory" {
    const testing = @import("std").testing;

    var m = [_]u8{0} ** 64;

    try testing.expectEqual(checkedAccess(&m, 5), &m[5]);
    try testing.expectEqual(checkedAccess(&m, 65), error.OutOfBounds);

    m[1] = 0xef;
    m[2] = 0xbe;
    try testing.expectEqual(try readByteAlignedCell(&m, 1), 0xbeef);

    try writeByteAlignedCell(&m, 1, 0xabcd);
    try testing.expectEqual(try readByteAlignedCell(&m, 1), 0xabcd);

    m[0] = 0x12;
    m[3] = 0x34;

    const slc = try sliceAt(&m, 0, 2);
    try testing.expectEqualSlices(vm.Cell, slc, &[_]vm.Cell{
        0xcd12,
        0x34ab,
    });
}
