const runtime = @import("runtime.zig");
const Cell = runtime.Cell;

const CircularStack = struct {
    stack: [32]Cell,
    idx: u8,

    fn peek(self: @This()) Cell {
        return self.stack[self.idx];
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
    top: Cell,
    second: Cell,
    inner: CircularStack,

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

    fn binop(self: *@This(), value: Cell) void {
        self.top = value;
        self.second = self.inner.pop();
    }

    pub fn eq(self: *@This()) void {
        const value = runtime.cellFromBoolean(self.second == self.top);
        self.binop(value);
    }

    // TODO should this use signed cells?
    pub fn gt(self: *@This()) void {
        const value = runtime.cellFromBoolean(self.second > self.top);
        self.binop(value);
    }

    // TODO should this use signed cells?
    pub fn gteq(self: *@This()) void {
        const value = runtime.cellFromBoolean(self.second >= self.top);
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

    pub fn add(self: *@This()) void {
        const value = self.second +% self.top;
        self.binop(value);
    }

    pub fn subtract(self: *@This()) void {
        const value = self.second -% self.top;
        self.binop(value);
    }

    pub fn multiply(self: *@This()) void {
        const value = self.second * self.top;
        self.binop(value);
    }

    pub fn divide(self: *@This()) void {
        var value: Cell = 0;
        if (self.top != 0) {
            value = self.second / self.top;
        }
        self.binop(value);
    }

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

test "stack: circular" {
    const testing = @import("std").testing;
    var cs: CircularStack = undefined;

    cs.push(0xbeef);
    try testing.expectEqual(0xbeef, cs.peek());
    try testing.expectEqual(0xbeef, cs.pop());
    cs.setTop(0x1234);
    try testing.expectEqual(0x1234, cs.peek());

    for (0..(cs.stack.len * 2)) |_| {
        _ = cs.pop();
    }

    for (0..(cs.stack.len * 2)) |_| {
        cs.push(0xabcd);
    }
}

test "stack: data" {
    const testing = @import("std").testing;
    var ds: DataStack = undefined;

    const forth_true = runtime.cellFromBoolean(true);
    const forth_false = runtime.cellFromBoolean(false);

    ds.push(0xbeef);
    try testing.expectEqual(0xbeef, ds.pop());

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

    // TODO
    // test invert true->false

    try testBinop(&ds, 0xbeef, 8, DataStack.lshift, 0xef00);
    try testBinop(&ds, 0xbeef, 8, DataStack.rshift, 0x00be);

    // TODO
    // inc
    // dec
    // stack manip

    try testBinop(&ds, 1234, 1, DataStack.add, 1235);
    try testBinop(&ds, 0xffff, 1, DataStack.add, 0x0000);
    try testBinop(&ds, 1234, 1, DataStack.subtract, 1233);
    try testBinop(&ds, 0x0000, 1, DataStack.subtract, 0xffff);
    try testBinop(&ds, 5, 5, DataStack.multiply, 25);
    try testBinop(&ds, 5, 5, DataStack.divide, 1);
    try testBinop(&ds, 5, 0, DataStack.divide, 0);
    try testBinop(&ds, 5, 5, DataStack.mod, 0);
    try testBinop(&ds, 7, 5, DataStack.mod, 2);
    try testBinop(&ds, 5, 0, DataStack.mod, 0);
}

fn testBinop(
    ds: *DataStack,
    second: Cell,
    top: Cell,
    operator: fn (_: *DataStack) void,
    expected: Cell,
) !void {
    const testing = @import("std").testing;
    ds.push(second);
    ds.push(top);
    operator(ds);
    try testing.expectEqual(expected, ds.pop());
}

test "stack: return" {
    const testing = @import("std").testing;
    var rs: ReturnStack = undefined;

    rs.push(0xbeef);
    try testing.expectEqual(0xbeef, rs.pop());
}
