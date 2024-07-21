const std = @import("std");
const Allocator = std.mem.Allocator;

pub const MiniVM = struct {
    const Cell = u16;

    const cell_size = @sizeOf(Cell);
    const mem_size = 32 * 1024;

    fn Stack(comptime count_: usize) type {
        return struct {
            const count = count_;
            const size = count * cell_size;
            top: *Cell,
            mem: *Cell,

            fn init(self: *@This(), top: *Cell, mem: *Cell) void {
                self.top = top;
                self.mem = mem;
                self.clear();
            }

            fn clear(self: @This()) void {
                self.top.* = self.mem.*;
            }
        };
    }

    const DataStack = Stack(32);
    const ReturnStack = Stack(32);

    allocator: Allocator,
    memory: []u8,
    data_stack: DataStack,

    const data_stack_top = 0;
    const data_stack_mem = data_stack_top + cell_size;
    const return_stack_top = data_stack_mem + DataStack.size;
    const return_stack_mem = return_stack_top + cell_size;

    pub fn init(self: *@This(), allocator: Allocator) !void {
        self.allocator = allocator;
        self.memory = try allocator.allocWithOptions(u8, mem_size, @alignOf(Cell), null);
        self.data_stack.init(@ptrCast(@alignCast(&self.memory[data_stack_top])), @ptrCast(@alignCast(&self.memory[data_stack_mem])));
        std.debug.print("{}", .{return_stack_top});
    }

    const mini = struct {
        fn exit() void {}
    };
};
