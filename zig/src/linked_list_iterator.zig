const mem = @import("memory.zig");
const MemoryPtr = mem.MemoryPtr;

const runtime = @import("runtime.zig");
const Cell = runtime.Cell;

pub const LinkedListIterator = struct {
    memory: MemoryPtr,
    last_addr: Cell,

    pub fn from(memory: MemoryPtr, first_addr: Cell) @This() {
        return .{
            .memory = memory,
            .last_addr = first_addr,
        };
    }

    pub fn next(self: *@This()) mem.Error!?Cell {
        if (self.last_addr == 0) {
            return null;
        }
        const ret = self.last_addr;
        self.last_addr = try mem.readCell(self.memory, self.last_addr);
        return ret;
    }
};

test "linked list iterator" {
    // TODO
}
