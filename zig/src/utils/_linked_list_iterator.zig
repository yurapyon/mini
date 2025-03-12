const mem = @import("../memory.zig");
const ConstMemoryPtr = mem.ConstMemoryPtr;

const runtime = @import("../runtime.zig");
const Cell = runtime.Cell;

// ===

pub const LinkedListIterator = struct {
    memory: ConstMemoryPtr,
    last_addr: Cell,

    pub fn from(memory: ConstMemoryPtr, first_addr: Cell) @This() {
        return .{
            .memory = memory,
            .last_addr = first_addr,
        };
    }

    pub fn next(self: *@This()) !?Cell {
        if (self.last_addr == 0) {
            return null;
        }
        const ret = self.last_addr;
        self.last_addr = try mem.readCell(self.memory, self.last_addr);
        return ret;
    }
};

test "linked list iterator" {
    const testing = @import("std").testing;

    const memory = try mem.allocateMemory(testing.allocator);
    defer testing.allocator.free(memory);

    const setup = [_]u8{
        // 0x1234
        0x34,
        0x12,

        // 0x0004
        0x04,
        0x00,

        // 0x0000
        0x00,
        0x00,

        // 0x0002
        0x02,
        0x00,
    };

    @memcpy(memory[0..setup.len], &setup);

    var iter = LinkedListIterator.from(memory, 0x0006);

    try testing.expectEqual(0x0006, iter.next());
    try testing.expectEqual(0x0002, iter.next());
    try testing.expectEqual(0x0004, iter.next());
    try testing.expectEqual(null, iter.next());
    try testing.expectEqual(null, iter.next());
}
