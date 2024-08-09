const runtime = @import("runtime.zig");
const Cell = runtime.Cell;

const CircularStack = struct {
    stack: [32]Cell,
    // TODO index could just be a u5 here
    idx: u8,

    fn peek(self: @This()) Cell {
        return self.stack[self.idx];
    }

    fn push(self: *@This(), value: Cell) void {
        self.idx = (self.idx + 1) % self.stack.len;
        self.stack[self.idx] = value;
    }

    fn pop(self: *@This()) Cell {
        const ret = self.peek();
        self.idx = (self.idx - 1) % self.stack.len;
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
