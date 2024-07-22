const vm = @import("MiniVM.zig");
const Cell = vm.Cell;
const Error = vm.Error;
const cellAccess = vm.cellAccess;

pub fn Stack(comptime count_: usize) type {
    return struct {
        pub const count = count_;
        pub const size = count * @sizeOf(Cell);

        memory: []u8,

        // top points to an empty Cell right beyond the actual topmost value
        top: *Cell,
        mem: *Cell,

        pub fn init(self: *@This(), memory: []u8, top: *Cell, mem: *Cell) void {
            self.memory = memory;
            self.top = top;
            self.mem = mem;
            self.clear();
        }

        pub fn depth(self: @This()) usize {
            const stack_size = self.top.* - self.mem.*;
            return stack_size / @sizeOf(Cell);
        }

        pub fn clear(self: @This()) void {
            self.top.* = self.mem.*;
        }

        pub fn unsafeIndex(self: *@This(), at: isize) Error!*Cell {
            const addr = @as(isize, self.top.*) - 1 + at;
            return try cellAccess(self.memory, @intCast(addr));
        }

        pub fn unsafeSwapValues(self: *@This(), a_idx: isize, b_idx: isize) Error!void {
            const a_cell = try self.unsafeIndex(a_idx);
            const b_cell = try self.unsafeIndex(b_idx);
            const temp = a_cell.*;
            a_cell.* = b_cell.*;
            b_cell.* = temp;
        }

        pub fn index(self: *@This(), at: usize) Error!*Cell {
            if (at >= self.depth()) {
                return Error.StackUnderflow;
            }
            return self.unsafeIndex(@intCast(at));
        }

        pub fn swapValues(self: *@This(), a_idx: usize, b_idx: usize) Error!void {
            const max_idx = @max(a_idx, b_idx);
            if (max_idx >= self.depth()) {
                return Error.StackUnderflow;
            }
            return self.unsafeSwapValues(@intCast(a_idx), @intCast(b_idx));
        }

        pub fn peek(self: *@This()) Error!Cell {
            const ptr = try self.index(0);
            return ptr.*;
        }

        pub fn push(self: *@This(), value: Cell) Error!void {
            const ptr = try self.unsafeIndex(-1);
            ptr.* = value;
            self.top.* += @sizeOf(Cell);
        }

        pub fn pop(self: *@This()) Error!Cell {
            const ret = try self.peek();
            self.top.* -= @sizeOf(Cell);
            return ret;
        }

        pub fn popCount(self: *@This(), comptime ct: usize) Error![ct]Cell {
            var ret = [_]Cell{0} ** ct;
            comptime var i = 0;
            inline while (i < ct) : (i += 1) {
                ret[i] = try self.pop();
            }
            return ret;
        }

        pub fn dup(self: *@This()) Error!void {
            try self.push(try self.peek());
        }

        pub fn drop(self: *@This()) Error!void {
            _ = try self.pop();
        }

        pub fn swap(self: *@This()) Error!void {
            try self.swapValues(0, 1);
        }

        pub fn rot(self: *@This()) Error!void {
            try self.swap();
            try self.flip();
        }

        pub fn nrot(self: *@This()) Error!void {
            try self.flip();
            try self.swap();
        }

        pub fn nip(self: *@This()) Error!void {
            try self.swap();
            try self.drop();
        }

        pub fn flip(self: *@This()) Error!void {
            try self.swapValues(0, 2);
        }

        pub fn tuck(self: *@This()) Error!void {
            try self.dup();
            try self.swapValues(1, 2);
        }

        pub fn over(self: *@This()) Error!void {
            const over_cell = try self.index(1);
            try self.push(over_cell.*);
        }
    };
}
