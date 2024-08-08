const runtime = @import("runtime.zig");
const Cell = runtime.Cell;

const CircularStack = struct {
    stack: [32]Cell,
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

    fn push(self: *@This(), value: Cell) void {
        self.inner.push(self.second);
        self.second = self.top;
        self.top = value;
    }

    fn pop(self: *@This()) Cell {
        const ret = self.top;
        self.top = self.second;
        self.second = self.inner.pop();
        return ret;
    }
};

pub const ReturnStack = struct {
    top: Cell,
    inner: CircularStack,

    fn push(self: *@This(), value: Cell) void {
        self.inner.push(self.top);
        self.top = value;
    }

    fn pop(self: *@This()) Cell {
        const ret = self.top;
        self.top = self.inner.pop();
        return ret;
    }
};
