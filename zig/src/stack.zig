const vm = @import("mini.zig");

const Range = @import("range.zig").Range;
const Register = @import("register.zig").Register;

pub const StackError = error{
// StackOverflow,
// StackUnderflow,
} || vm.mem.MemoryError;

/// Stack
pub fn Stack(
    comptime top_offset: vm.Cell,
    comptime range_: Range,
) type {
    return struct {
        comptime {
            if (range.start >= range.end) {
                @compileError("Invalid stack range");
            }
            if (!range.alignedTo(@alignOf(vm.Cell))) {
                @compileError("Stack range must be vm.Cell aligned");
            }
        }

        pub const range = range_;
        pub const MemType = [range.sizeExclusive()]u8;

        memory: vm.mem.CellAlignedMemory,
        top: Register(top_offset),

        pub fn initInOneMemoryBlock(
            self: *@This(),
            memory: vm.mem.CellAlignedMemory,
        ) vm.mem.MemoryError!void {
            self.memory = memory;
            try self.top.init(self.memory);
            if (range.start >= self.memory.len or range.end >= self.memory.len) {
                return error.OutOfBounds;
            }
            self.clear();
        }

        pub fn clear(self: @This()) void {
            self.top.store(range.start);
        }

        fn wrappedAddress(addr: vm.Cell) vm.Cell {
            return range.wrapWithin(addr);
        }

        pub fn index(self: *@This(), at: vm.Cell) *vm.Cell {
            const top = self.top.fetch();
            const addr = top - at * @sizeOf(vm.Cell);
            // NOTE
            // this cellAt access won't fail because top.fetch()
            //   is only ever changed by sizeOf(Cell), and the range it's
            //      wrapped within was verified on init
            return vm.mem.cellAt(self.memory, wrappedAddress(addr)) catch unreachable;
        }

        pub fn swapValues(
            self: *@This(),
            a_idx: vm.Cell,
            b_idx: vm.Cell,
        ) void {
            const a_cell = self.index(a_idx);
            const b_cell = self.index(b_idx);
            const temp = a_cell.*;
            a_cell.* = b_cell.*;
            b_cell.* = temp;
        }

        pub fn peek(self: *@This()) vm.Cell {
            return self.index(0).*;
        }

        pub fn push(
            self: *@This(),
            value: vm.Cell,
        ) void {
            const addr = self.top.fetch();
            const write_to = wrappedAddress(addr + @sizeOf(vm.Cell));
            self.top.store(write_to);
            self.index(0).* = value;
        }

        pub fn pop(self: *@This()) vm.Cell {
            const ret = self.peek();
            const addr = self.top.fetch();
            self.top.store(wrappedAddress(addr - @sizeOf(vm.Cell)));
            return ret;
        }

        pub fn popMultiple(
            self: *@This(),
            comptime ct: usize,
        ) [ct]vm.Cell {
            var ret = [_]vm.Cell{0} ** ct;
            comptime var i = 0;
            inline while (i < ct) : (i += 1) {
                ret[i] = self.pop();
            }
            return ret;
        }

        pub fn dup(self: *@This()) void {
            self.push(self.peek());
        }

        pub fn drop(self: *@This()) void {
            _ = self.pop();
        }

        pub fn swap(self: *@This()) void {
            self.swapValues(0, 1);
        }

        pub fn rot(self: *@This()) void {
            self.swap();
            self.flip();
        }

        pub fn nrot(self: *@This()) void {
            self.flip();
            self.swap();
        }

        pub fn nip(self: *@This()) void {
            self.swap();
            self.drop();
        }

        pub fn flip(self: *@This()) void {
            self.swapValues(0, 2);
        }

        pub fn tuck(self: *@This()) void {
            self.dup();
            self.swapValues(1, 2);
        }

        pub fn over(self: *@This()) void {
            const over_cell = self.index(1);
            self.push(over_cell.*);
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

    var stack: Stack(0, .{ .start = 2, .end = 32 }) = undefined;
    try stack.initInOneMemoryBlock(memory);

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
