const vm = @import("mini.zig");

const Register = @import("register.zig").Register;

// TODO handle stack overflows

/// Stack
pub fn Stack(comptime count_: usize) type {
    return struct {
        pub const count = count_;
        pub const size = count * @sizeOf(vm.Cell);
        pub const MemType = [size]u8;

        memory: vm.Memory,

        // top.fetch() is a ptr to
        //   empty Cell right beyond the actual topmost value
        top: Register,
        bottom_offset: vm.Cell,

        pub fn init(
            self: *@This(),
            memory: vm.Memory,
            top_offset: vm.Cell,
            bottom_offset: vm.Cell,
        ) void {
            self.memory = memory;
            self.top.init(self.memory, top_offset);
            self.bottom_offset = bottom_offset;
            self.clear();
        }

        pub fn depth(self: @This()) usize {
            const stack_size = self.top.fetch() - self.bottom_offset;
            return stack_size / @sizeOf(vm.Cell);
        }

        pub fn clear(self: @This()) void {
            self.top.store(self.bottom_offset);
        }

        fn unsafeIndex(self: *@This(), at: isize) vm.Error!*vm.Cell {
            const addr = @as(isize, @intCast(self.top.fetch())) - (at + 1) * @sizeOf(vm.Cell);
            return vm.cellAt(self.memory, @intCast(addr));
        }

        fn unsafeSwapValues(
            self: *@This(),
            a_idx: isize,
            b_idx: isize,
        ) vm.Error!void {
            const a_cell = try self.unsafeIndex(a_idx);
            const b_cell = try self.unsafeIndex(b_idx);
            const temp = a_cell.*;
            a_cell.* = b_cell.*;
            b_cell.* = temp;
        }

        pub fn index(self: *@This(), at: usize) vm.Error!*vm.Cell {
            if (at >= self.depth()) {
                return error.StackUnderflow;
            }
            return self.unsafeIndex(@intCast(at));
        }

        pub fn swapValues(
            self: *@This(),
            a_idx: usize,
            b_idx: usize,
        ) vm.Error!void {
            const max_idx = @max(a_idx, b_idx);
            if (max_idx >= self.depth()) {
                return error.StackUnderflow;
            }
            return self.unsafeSwapValues(@intCast(a_idx), @intCast(b_idx));
        }

        pub fn peek(self: *@This()) vm.Error!vm.Cell {
            const ptr = try self.index(0);
            return ptr.*;
        }

        pub fn push(self: *@This(), value: vm.Cell) vm.Error!void {
            const ptr = try self.unsafeIndex(-1);
            ptr.* = value;
            self.top.storeAdd(@sizeOf(vm.Cell));
        }

        pub fn pop(self: *@This()) vm.Error!vm.Cell {
            const ret = try self.peek();
            self.top.storeSubtract(@sizeOf(vm.Cell));
            return ret;
        }

        pub fn popMultiple(self: *@This(), comptime ct: usize) vm.Error![ct]vm.Cell {
            var ret = [_]vm.Cell{0} ** ct;
            comptime var i = 0;
            inline while (i < ct) : (i += 1) {
                ret[i] = try self.pop();
            }
            return ret;
        }

        pub fn dup(self: *@This()) vm.Error!void {
            try self.push(try self.peek());
        }

        pub fn drop(self: *@This()) vm.Error!void {
            _ = try self.pop();
        }

        pub fn swap(self: *@This()) vm.Error!void {
            try self.swapValues(0, 1);
        }

        pub fn rot(self: *@This()) vm.Error!void {
            try self.swap();
            try self.flip();
        }

        pub fn nrot(self: *@This()) vm.Error!void {
            try self.flip();
            try self.swap();
        }

        pub fn nip(self: *@This()) vm.Error!void {
            try self.swap();
            try self.drop();
        }

        pub fn flip(self: *@This()) vm.Error!void {
            try self.swapValues(0, 2);
        }

        pub fn tuck(self: *@This()) vm.Error!void {
            try self.dup();
            try self.swapValues(1, 2);
        }

        pub fn over(self: *@This()) vm.Error!void {
            const over_cell = try self.index(1);
            try self.push(over_cell.*);
        }
    };
}

test "stack" {
    const testing = @import("std").testing;

    const memory = try vm.allocateMemory(testing.allocator);
    defer testing.allocator.free(memory);

    var stack: Stack32 = undefined;
    stack.init(memory, 0, 2);

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

const Stack32 = Stack(32);

pub fn expectStack(stack: Stack32, expectation: []const vm.Cell) !void {
    const testing = @import("std").testing;
    const mem: [*]vm.Cell = @ptrCast(@alignCast(&stack.memory[stack.bottom_offset]));
    try testing.expectEqualSlices(
        vm.Cell,
        expectation,
        mem[0..expectation.len],
    );
}
