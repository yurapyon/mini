const vm = @import("mini.zig");

const Range = @import("range.zig").Range;
const Register = @import("register.zig").Register;

pub const StackError = error{
    StackOverflow,
    StackUnderflow,
} || vm.mem.MemoryError;

/// Stack
pub fn Stack(
    comptime top_offset: vm.Cell,
    comptime range_: Range,
) type {
    return struct {
        comptime {
            if (!range.alignedTo(@alignOf(vm.Cell))) {
                @compileError("Stack range must be vm.Cell aligned");
            }
        }

        pub const range = range_;
        pub const MemType = [range.sizeExclusive()]u8;

        top: Register(top_offset),
        memory: vm.mem.CellAlignedMemory,

        pub fn depth(self: @This()) vm.Cell {
            const top = self.top.fetch();
            const stack_size = top - range.start;
            return stack_size / @sizeOf(vm.Cell);
        }

        pub fn asSlice(self: *@This()) vm.mem.MemoryError![]vm.Cell {
            return vm.mem.sliceAt(self.memory, range.start, self.depth());
        }

        pub fn clear(self: @This()) void {
            self.top.store(range.start);
        }

        pub fn index(self: *@This(), at: usize) StackError!*vm.Cell {
            if (at >= self.depth()) {
                return error.StackUnderflow;
            }
            const top = self.top.fetch();
            const addr = top - (at + 1) * @sizeOf(vm.Cell);
            return try vm.mem.cellAt(self.memory, @intCast(addr));
        }

        pub fn swapValues(
            self: *@This(),
            a_idx: usize,
            b_idx: usize,
        ) StackError!void {
            const a_cell = try self.index(a_idx);
            const b_cell = try self.index(b_idx);
            const temp = a_cell.*;
            a_cell.* = b_cell.*;
            b_cell.* = temp;
        }

        pub fn peek(self: @This()) StackError!vm.Cell {
            const addr = self.top.fetch();
            if (addr == range.start) {
                return error.StackUnderflow;
            }
            return (try vm.mem.cellAt(self.memory, addr - @sizeOf(vm.Cell))).*;
        }

        pub fn push(
            self: @This(),
            value: vm.Cell,
        ) StackError!void {
            const addr = self.top.fetch();
            if (addr >= range.end) {
                return error.StackOverflow;
            }
            self.top.storeAdd(@sizeOf(vm.Cell));
            (try vm.mem.cellAt(self.memory, addr)).* = value;
        }

        pub fn pop(self: @This()) StackError!vm.Cell {
            const ret = try self.peek();
            self.top.storeSubtract(@sizeOf(vm.Cell));
            return ret;
        }

        pub fn popMultiple(
            self: *@This(),
            comptime ct: usize,
        ) StackError![ct]vm.Cell {
            var ret = [_]vm.Cell{0} ** ct;
            comptime var i = 0;
            inline while (i < ct) : (i += 1) {
                ret[i] = try self.pop();
            }
            return ret;
        }

        pub fn dup(self: *@This()) StackError!void {
            try self.push(try self.peek());
        }

        pub fn drop(self: *@This()) StackError!void {
            _ = try self.pop();
        }

        pub fn swap(self: *@This()) StackError!void {
            try self.swapValues(0, 1);
        }

        pub fn rot(self: *@This()) StackError!void {
            try self.swap();
            try self.flip();
        }

        pub fn nrot(self: *@This()) StackError!void {
            try self.flip();
            try self.swap();
        }

        pub fn nip(self: *@This()) StackError!void {
            try self.swap();
            try self.drop();
        }

        pub fn flip(self: *@This()) StackError!void {
            try self.swapValues(0, 2);
        }

        pub fn tuck(self: *@This()) StackError!void {
            try self.dup();
            try self.swapValues(1, 2);
        }

        pub fn over(self: *@This()) StackError!void {
            const over_cell = try self.index(1);
            try self.push(over_cell.*);
        }
    };
}

test "stack" {
    const testing = @import("std").testing;

    const memory = try vm.mem.allocateCellAlignedMemory(
        testing.allocator,
        vm.max_memory_size,
    );
    defer testing.allocator.free(memory);

    var stack = Stack(0, .{ .start = 2, .end = 32 }){
        .top = .{
            .memory = memory,
        },
        .memory = memory,
    };

    stack.clear();
    try testing.expectEqual(0, stack.depth());

    try stack.push(0);
    try stack.push(1);
    try stack.push(2);
    try expectStack(stack, &[_]vm.Cell{ 0, 1, 2 });

    try testing.expectEqual(2, try stack.pop());

    try stack.tuck();
    try expectStack(stack, &[_]vm.Cell{ 1, 0, 1 });

    try stack.drop();
    try stack.swap();
    try stack.push(2);
    try expectStack(stack, &[_]vm.Cell{ 0, 1, 2 });

    try stack.rot();
    try expectStack(stack, &[_]vm.Cell{ 1, 2, 0 });

    try stack.nrot();
    try expectStack(stack, &[_]vm.Cell{ 0, 1, 2 });

    try stack.flip();
    try stack.nip();
    try stack.over();
    try expectStack(stack, &[_]vm.Cell{ 2, 0, 2 });

    try stack.dup();
    try expectStack(stack, &[_]vm.Cell{ 2, 0, 2, 2 });

    const a, const b, const c, const d = try stack.popMultiple(4);
    try testing.expectEqual(2, a);
    try testing.expectEqual(2, b);
    try testing.expectEqual(0, c);
    try testing.expectEqual(2, d);

    try testing.expectEqual(0, stack.depth());
}

pub fn expectStack(stack: anytype, expectation: []const vm.Cell) !void {
    const S = @TypeOf(stack);

    const testing = @import("std").testing;
    const mem: [*]vm.Cell = @ptrCast(@alignCast(&stack.memory[S.range.start]));
    try testing.expectEqualSlices(
        vm.Cell,
        expectation,
        mem[0..expectation.len],
    );
}
