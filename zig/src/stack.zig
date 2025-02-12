const runtime = @import("runtime.zig");
const Cell = runtime.Cell;
const SignedCell = runtime.SignedCell;

// ===

const stack_inner_depth = 64;

const CircularStack = struct {
    stack: [stack_inner_depth]Cell,
    idx: u8,

    fn peek(self: @This()) Cell {
        return self.stack[self.idx];
    }

    pub fn index(self: *@This(), idx: u8) Cell {
        return self.stack[self.idx +% idx];
    }

    fn setTop(self: *@This(), value: Cell) void {
        self.stack[self.idx] = value;
    }

    fn push(self: *@This(), value: Cell) void {
        const u8_len: u8 = @intCast(self.stack.len);
        self.idx = (self.idx +% 1) % u8_len;
        self.stack[self.idx] = value;
    }

    fn pop(self: *@This()) Cell {
        const ret = self.peek();
        const u8_len: u8 = @intCast(self.stack.len);
        self.idx = (self.idx -% 1) % u8_len;
        return ret;
    }
};

pub const DataStack = struct {
    // TODO what in here should use signed cells?
    // everything maybe ?

    top: Cell,
    second: Cell,
    inner: CircularStack,

    pub fn peek(self: *@This()) Cell {
        return self.top;
    }

    pub fn index(self: *@This(), idx: u8) Cell {
        // TODO
        // This has to wrap around 66
        if (idx == 0) {
            return self.top;
        } else if (idx == 1) {
            return self.second;
        } else {
            return self.inner.index(idx -% 2);
        }
    }

    pub fn push(self: *@This(), value: Cell) void {
        self.inner.push(self.second);
        self.second = self.top;
        self.top = value;
    }

    pub fn pop(self: *@This()) Cell {
        const ret = self.top;
        self.top = self.second;
        self.second = self.inner.pop();
        return ret;
    }

    pub fn pop2(self: *@This()) [2]Cell {
        const a = self.top;
        const b = self.second;
        self.top = self.inner.pop();
        self.second = self.inner.pop();
        return .{ a, b };
    }

    fn binop(self: *@This(), value: Cell) void {
        self.top = value;
        self.second = self.inner.pop();
    }

    pub fn eq(self: *@This()) void {
        const value = runtime.cellFromBoolean(self.second == self.top);
        self.binop(value);
    }

    pub fn eq0(self: *@This()) void {
        self.top = runtime.cellFromBoolean(self.top == 0);
    }

    pub fn gt(self: *@This()) void {
        const signed_top: SignedCell = @bitCast(self.top);
        const signed_second: SignedCell = @bitCast(self.second);
        const value = runtime.cellFromBoolean(signed_second > signed_top);
        self.binop(value);
    }

    pub fn gteq(self: *@This()) void {
        const signed_top: SignedCell = @bitCast(self.top);
        const signed_second: SignedCell = @bitCast(self.second);
        const value = runtime.cellFromBoolean(signed_second >= signed_top);
        self.binop(value);
    }

    pub fn lt(self: *@This()) void {
        const signed_top: SignedCell = @bitCast(self.top);
        const signed_second: SignedCell = @bitCast(self.second);
        const value = runtime.cellFromBoolean(signed_second < signed_top);
        self.binop(value);
    }

    pub fn lteq(self: *@This()) void {
        const signed_top: SignedCell = @bitCast(self.top);
        const signed_second: SignedCell = @bitCast(self.second);
        const value = runtime.cellFromBoolean(signed_second <= signed_top);
        self.binop(value);
    }

    pub fn and_(self: *@This()) void {
        const value = self.second & self.top;
        self.binop(value);
    }

    pub fn ior(self: *@This()) void {
        const value = self.second | self.top;
        self.binop(value);
    }

    pub fn xor(self: *@This()) void {
        const value = self.second ^ self.top;
        self.binop(value);
    }

    pub fn invert(self: *@This()) void {
        self.top = ~self.top;
    }

    pub fn lshift(self: *@This()) void {
        const value = self.second << @truncate(self.top);
        self.binop(value);
    }

    pub fn rshift(self: *@This()) void {
        const value = self.second >> @truncate(self.top);
        self.binop(value);
    }

    pub fn inc(self: *@This()) void {
        self.top +%= 1;
    }

    pub fn dec(self: *@This()) void {
        self.top -%= 1;
    }

    pub fn drop(self: *@This()) void {
        _ = self.pop();
    }

    pub fn dup(self: *@This()) void {
        self.inner.push(self.second);
        self.second = self.top;
    }

    pub fn swap(self: *@This()) void {
        const temp = self.top;
        self.top = self.second;
        self.second = temp;
    }

    pub fn flip(self: *@This()) void {
        const temp = self.top;
        self.top = self.inner.peek();
        self.inner.setTop(temp);
    }

    pub fn over(self: *@This()) void {
        self.push(self.second);
    }

    pub fn nip(self: *@This()) void {
        self.second = self.inner.pop();
    }

    pub fn tuck(self: *@This()) void {
        self.inner.push(self.top);
    }

    pub fn rot(self: *@This()) void {
        self.push(self.inner.pop());
    }

    pub fn nrot(self: *@This()) void {
        self.inner.push(self.pop());
    }

    pub fn add(self: *@This()) void {
        const value = self.second +% self.top;
        self.binop(value);
    }

    pub fn subtract(self: *@This()) void {
        const value = self.second -% self.top;
        self.binop(value);
    }

    pub fn multiply(self: *@This()) void {
        const value = self.second *% self.top;
        self.binop(value);
    }

    // TODO these should be signed
    pub fn divide(self: *@This()) void {
        var value: Cell = 0;
        if (self.top != 0) {
            value = self.second / self.top;
        }
        self.binop(value);
    }

    // TODO these should be signed
    pub fn mod(self: *@This()) void {
        var value: Cell = 0;
        if (self.top != 0) {
            value = self.second % self.top;
        }
        self.binop(value);
    }
};

pub const ReturnStack = struct {
    top: Cell,
    inner: CircularStack,

    pub fn peek(self: *@This()) Cell {
        return self.top;
    }

    pub fn push(self: *@This(), value: Cell) void {
        self.inner.push(self.top);
        self.top = value;
    }

    pub fn pop(self: *@This()) Cell {
        const ret = self.top;
        self.top = self.inner.pop();
        return ret;
    }
};

// tests ===

fn testCommon(
    stack: anytype,
) !void {
    const testing = @import("std").testing;

    const value = 0xbeef;
    stack.push(value);
    try testing.expectEqual(value, stack.pop());

    for (0..(stack_inner_depth * 2)) |_| {
        _ = stack.pop();
    }

    for (0..(stack_inner_depth * 2)) |_| {
        stack.push(0xabcd);
    }
}

fn testUnop(
    stack: anytype,
    value: Cell,
    operator: fn (_: @TypeOf(stack)) void,
    expected: Cell,
) !void {
    const testing = @import("std").testing;
    stack.push(value);
    operator(stack);
    try testing.expectEqual(expected, stack.pop());
}

fn testBinop(
    stack: anytype,
    second: Cell,
    top: Cell,
    operator: fn (_: @TypeOf(stack)) void,
    expected: Cell,
) !void {
    const testing = @import("std").testing;
    stack.push(second);
    stack.push(top);
    operator(stack);
    try testing.expectEqual(expected, stack.pop());
}

fn testStackManipulator(
    stack: anytype,
    setup: []const Cell,
    operator: fn (_: @TypeOf(stack)) void,
    expected: []const Cell,
) !void {
    const testing = @import("std").testing;
    for (setup) |value| {
        stack.push(value);
    }
    operator(stack);
    for (0..(expected.len)) |i| {
        const idx = expected.len - i - 1;
        try testing.expectEqual(expected[idx], stack.pop());
    }
}

test "stack: circular" {
    const testing = @import("std").testing;
    var cs: CircularStack = undefined;

    try testCommon(&cs);

    cs.push(0xbeef);
    try testing.expectEqual(0xbeef, cs.peek());
    cs.setTop(0x1234);
    try testing.expectEqual(0x1234, cs.peek());
}

test "stack: data" {
    var ds: DataStack = undefined;

    try testCommon(&ds);

    const forth_true = runtime.cellFromBoolean(true);
    const forth_false = runtime.cellFromBoolean(false);

    try testBinop(&ds, 0xbeef, 0xbeef, DataStack.eq, forth_true);
    try testBinop(&ds, 0x1234, 0xbeef, DataStack.eq, forth_false);

    try testBinop(&ds, 0x0, 0x1, DataStack.gt, forth_false);
    try testBinop(&ds, 0x0, 0x0, DataStack.gt, forth_false);
    try testBinop(&ds, 0x1, 0x0, DataStack.gt, forth_true);

    try testBinop(&ds, 0x0, 0x1, DataStack.gteq, forth_false);
    try testBinop(&ds, 0x0, 0x0, DataStack.gteq, forth_true);
    try testBinop(&ds, 0x1, 0x0, DataStack.gteq, forth_true);

    try testBinop(&ds, 0xbe00, 0x00ef, DataStack.and_, 0x0000);
    try testBinop(&ds, 0xbe00, 0x00ef, DataStack.ior, 0xbeef);
    try testBinop(&ds, 0xbe00, 0x00ef, DataStack.xor, 0xbeef);
    try testBinop(&ds, 0x0000, 0x1111, DataStack.xor, 0x1111);

    try testUnop(&ds, forth_true, DataStack.invert, forth_false);

    try testBinop(&ds, 0xbeef, 8, DataStack.lshift, 0xef00);
    try testBinop(&ds, 0xbeef, 8, DataStack.rshift, 0x00be);

    try testUnop(&ds, 1, DataStack.inc, 2);
    try testUnop(&ds, 0xffff, DataStack.inc, 0x0000);
    try testUnop(&ds, 2, DataStack.dec, 1);
    try testUnop(&ds, 0x0000, DataStack.dec, 0xffff);

    try testStackManipulator(
        &ds,
        &[_]Cell{ 1, 2, 3 },
        DataStack.drop,
        &[_]Cell{ 1, 2 },
    );

    try testStackManipulator(
        &ds,
        &[_]Cell{ 1, 2, 3 },
        DataStack.dup,
        &[_]Cell{ 1, 2, 3, 3 },
    );

    try testStackManipulator(
        &ds,
        &[_]Cell{ 1, 2, 3 },
        DataStack.swap,
        &[_]Cell{ 1, 3, 2 },
    );

    try testStackManipulator(
        &ds,
        &[_]Cell{ 1, 2, 3 },
        DataStack.flip,
        &[_]Cell{ 3, 2, 1 },
    );

    try testStackManipulator(
        &ds,
        &[_]Cell{ 1, 2, 3 },
        DataStack.over,
        &[_]Cell{ 1, 2, 3, 2 },
    );

    try testStackManipulator(
        &ds,
        &[_]Cell{ 1, 2, 3 },
        DataStack.nip,
        &[_]Cell{ 1, 3 },
    );

    try testStackManipulator(
        &ds,
        &[_]Cell{ 1, 2, 3 },
        DataStack.tuck,
        &[_]Cell{ 1, 3, 2, 3 },
    );

    try testStackManipulator(
        &ds,
        &[_]Cell{ 1, 2, 3 },
        DataStack.rot,
        &[_]Cell{ 2, 3, 1 },
    );

    try testStackManipulator(
        &ds,
        &[_]Cell{ 1, 2, 3 },
        DataStack.nrot,
        &[_]Cell{ 3, 1, 2 },
    );

    try testBinop(&ds, 1234, 2, DataStack.add, 1236);
    try testBinop(&ds, 0xffff, 2, DataStack.add, 0x0001);
    try testBinop(&ds, 1234, 2, DataStack.subtract, 1232);
    try testBinop(&ds, 0x0000, 2, DataStack.subtract, 0xfffe);
    try testBinop(&ds, 5, 5, DataStack.multiply, 25);
    try testBinop(&ds, 5, 5, DataStack.divide, 1);
    try testBinop(&ds, 5, 0, DataStack.divide, 0);
    try testBinop(&ds, 5, 5, DataStack.mod, 0);
    try testBinop(&ds, 7, 5, DataStack.mod, 2);
    try testBinop(&ds, 5, 0, DataStack.mod, 0);
}

test "stack: return" {
    var rs: ReturnStack = undefined;

    try testCommon(&rs);
}
