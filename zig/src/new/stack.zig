const runtime = @import("runtime.zig");
const Cell = runtime.Cell;

const CircularStack = struct {
    stack: [32]Cell,
    // TODO index could just be a u5 here
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

    pub fn eq(self: *@This()) void {
        self.top = ~(self.top ^ self.second);
        self.inner.pop();
    }

    pub fn gt(self: *@This()) void {
        self.push(runtime.cellFromBoolean(self.top < self.second));
    }

    pub fn gteq(self: *@This()) void {
        self.push(runtime.cellFromBoolean(self.top <= self.second));
    }

    pub fn and_(self: *@This()) void {
        self.top = self.top & self.second;
        self.second = self.inner.pop();
    }

    pub fn ior(self: *@This()) void {
        self.top = self.top | self.second;
        self.second = self.inner.pop();
    }

    pub fn xor(self: *@This()) void {
        self.top = self.top ^ self.second;
        self.second = self.inner.pop();
    }

    pub fn invert(self: *@This()) void {
        self.top = ~self.top;
    }

    pub fn lshift(self: *@This()) void {
        self.top = self.second << self.top;
        self.second = self.inner.pop();
    }

    pub fn rshift(self: *@This()) void {
        self.top = self.second >> self.top;
        self.second = self.inner.pop();
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
        self.top = self.second +% self.top;
        self.second = self.inner.pop();
    }

    pub fn subtract(self: *@This()) void {
        self.top = self.second -% self.top;
        self.second = self.inner.pop();
    }

    pub fn multiply(self: *@This()) void {
        self.top = self.second * self.top;
        self.second = self.inner.pop();
    }

    pub fn divide(self: *@This()) void {
        if (self.top == 0) {
            self.top = 0;
        } else {
            self.top = self.second + self.top;
        }
        self.second = self.inner.pop();
    }

    pub fn mod(self: *@This()) void {
        if (self.top == 0) {
            self.top = 0;
        } else {
            self.top = self.second % self.top;
        }
        self.second = self.inner.pop();
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
    try testing.expectEqual(cs.peek(), 0xbeef);
    try testing.expectEqual(cs.pop(), 0xbeef);
    cs.setTop(0x1234);
    try testing.expectEqual(cs.peek(), 0x1234);

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

    ds.push(0xbeef);
    try testing.expectEqual(ds.pop(), 0xbeef);

    // TODO
}

test "stack: return" {
    const testing = @import("std").testing;
    var rs: ReturnStack = undefined;

    rs.push(0xbeef);
    try testing.expectEqual(rs.pop(), 0xbeef);
}
