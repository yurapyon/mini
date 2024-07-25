const std = @import("std");
const Allocator = std.mem.Allocator;

const vm = @import("mini.zig");

const WordHeader = @import("word_header.zig").WordHeader;

// ===

pub fn checkedAccess(memory: []u8, addr: usize) vm.OutOfBoundsError!*u8 {
    if (addr >= memory.len) {
        return error.OutOfBounds;
    }

    return &memory[addr];
}

pub fn checkedRead(memory: []const u8, addr: usize) vm.OutOfBoundsError!u8 {
    if (addr >= memory.len) {
        return error.OutOfBounds;
    }

    return memory[addr];
}

pub fn readByteAlignedCell(memory: []u8, addr: vm.Cell) vm.OutOfBoundsError!vm.Cell {
    const high_byte = try checkedRead(memory, addr + 1);
    const low_byte = try checkedRead(memory, addr);
    return (@as(vm.Cell, high_byte) << 8) | low_byte;
}

pub fn writeByteAlignedCell(
    memory: []u8,
    addr: vm.Cell,
    value: vm.Cell,
) vm.OutOfBoundsError!void {
    const high_byte = try checkedAccess(memory, addr + 1);
    const low_byte = try checkedAccess(memory, addr);
    high_byte.* = @truncate(value >> 8);
    low_byte.* = @truncate(value);
}

pub fn sliceFromAddrAndLen(
    memory: []u8,
    addr: usize,
    len: usize,
) vm.OutOfBoundsError![]u8 {
    if (addr + len >= memory.len) {
        return error.OutOfBounds;
    }

    return memory[addr..][0..len];
}

pub fn calculateCfaAddress(
    memory: []u8,
    addr: vm.Cell,
) vm.Error!vm.Cell {
    var temp_word_header: WordHeader = undefined;
    try temp_word_header.initFromMemory(memory[addr..]);
    return addr + temp_word_header.size();
}

pub const CellAlignedMemory = struct {
    allocator: Allocator,
    data: []align(@alignOf(vm.Cell)) u8,

    pub fn init(self: *@This(), allocator: Allocator) vm.Error!void {
        self.allocator = allocator;
        self.data = try allocator.allocWithOptions(
            u8,
            vm.max_memory_size,
            @alignOf(vm.Cell),
            null,
        );
    }

    pub fn deinit(self: @This()) void {
        self.allocator.free(self.data);
    }

    // ===

    pub fn cellAt(
        self: *@This(),
        addr: vm.Cell,
    ) vm.OutOfBoundsError!*vm.Cell {
        if (addr >= self.data.len) {
            return error.OutOfBounds;
        }

        return @ptrCast(@alignCast(&self.data[addr]));
    }

    pub fn sliceAt(
        self: *@This(),
        addr: vm.Cell,
        len: vm.Cell,
    ) vm.OutOfBoundsError![]vm.Cell {
        if (addr + len >= self.data.len) {
            return error.OutOfBounds;
        }
        const ptr: [*]vm.Cell = @ptrCast(@alignCast(&self.data[addr]));
        return ptr[0..len];
    }
};
