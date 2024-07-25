const vm = @import("mini.zig");

const WordHeader = @import("word_header.zig").WordHeader;

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

pub fn readByteAlignedCell(
    memory: []const u8,
    addr: usize,
) vm.OutOfBoundsError!vm.Cell {
    const high_byte = try checkedRead(memory, addr + 1);
    const low_byte = try checkedRead(memory, addr);
    return (@as(vm.Cell, high_byte) << 8) | low_byte;
}

pub fn writeByteAlignedCell(
    memory: []u8,
    addr: usize,
    value: vm.Cell,
) vm.OutOfBoundsError!void {
    const high_byte = try checkedAccess(memory, addr + 1);
    const low_byte = try checkedAccess(memory, addr);
    high_byte.* = @truncate(value >> 8);
    low_byte.* = @truncate(value);
}

pub fn cellAt(memory: []u8, addr: vm.Cell) vm.OutOfBoundsError!*vm.Cell {
    if (addr >= memory.len) {
        return error.OutOfBounds;
    }
    return @ptrCast(@alignCast(&memory[addr]));
}

pub fn sliceAt(memory: []u8, addr: vm.Cell, len: vm.Cell) vm.OutOfBoundsError![]vm.Cell {
    if (addr + len >= memory.len) {
        return error.OutOfBounds;
    }
    const ptr: [*]vm.Cell = @ptrCast(@alignCast(&memory[addr]));
    return ptr[0..len];
}

pub fn calculateCfaAddress(memory: []u8, addr: vm.Cell) vm.Error!vm.Cell {
    var temp_word_header: WordHeader = undefined;
    try temp_word_header.initFromMemory(memory[addr..]);
    return addr + temp_word_header.size();
}
