const runtime = @import("runtime.zig");
const Cell = runtime.Cell;

pub const Error = error{
    MisalignedAddress,
};

pub fn assertCellAccess(addr: Cell) Error!void {
    if (addr % @alignOf(Cell) == 0) {
        return error.MisalignedAddress;
    }
}

pub fn readCell(memory: []const u8, addr: Cell) Error!Cell {
    try assertCellAccess(addr);
    const cell_ptr: *const Cell = @ptrCast(@alignCast(&memory[addr]));
    return cell_ptr.*;
}

pub fn writeCell(memory: []u8, addr: Cell, value: Cell) Error!void {
    try assertCellAccess(addr);
    const cell_ptr: *const Cell = @ptrCast(@alignCast(&memory[addr]));
    cell_ptr.* = value;
}
