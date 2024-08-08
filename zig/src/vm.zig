// bytecode list
// >r
// r>
// jump
// call
// br
// 0br
// lit

const Cell = u16;

/// Basically a 16bit version of the F18
///   some opcodes are added for convenience
pub const VM = struct {
    data_stack: DataStack,
    return_stack: ReturnStack,
    registers: struct {
        p: Cell,
        a: Cell,
        b: Cell,
    },
    memory: [64 * 1024]u8,

    // program control ===

    fn exit(self: *@This()) void {
        self.registers.p = self.return_stack.pop();
    }

    fn execute(self: *@This()) void {
        const temp = self.return_stack.top;
        self.return_stack.top = self.registers.p;
        self.registers.p = temp;
    }

    fn jump(self: *@This()) void {
        // TODO where is the address kept?
        _ = self;
    }

    fn call(self: *@This()) void {
        // TODO where is the address kept?
        _ = self;
    }

    fn unext(self: *@This()) void {
        // TODO this probably isn't relevant
        _ = self;
    }

    fn next(self: *@This()) void {
        // TODO where is the address kept?
        const addr = self.return_stack.top;
        if (addr == 0) {
            _ = self.return_stack.pop();
        }
    }

    fn branch0(self: *@This()) void {
        // TODO where is the address kept?
        _ = self;
    }

    fn branchPositive(self: *@This()) void {
        // TODO where is the address kept?
        _ = self;
    }

    // memory ===

    fn fetchP(self: *@This()) void {
        const value = self.memory[self.registers.p];
        self.data_stack.push(value);
        self.registers.p += @sizeOf(Cell);
    }

    fn fetchPlus(self: *@This()) void {
        self.fetch();
        self.registers.a += @sizeOf(Cell);
    }

    fn fetchB(self: *@This()) void {
        const value = self.memory[self.registers.b];
        self.data_stack.push(value);
    }

    fn fetch(self: *@This()) void {
        const value = self.memory[self.registers.a];
        self.data_stack.push(value);
    }

    fn storeP(self: *@This()) void {
        const value = self.data_stack.pop();
        self.memory[self.registers.p] = value;
        self.registers.p += @sizeOf(Cell);
    }

    fn storePlus(self: *@This()) void {
        self.store();
        self.registers.a += @sizeOf(Cell);
    }

    fn storeB(self: *@This()) void {
        const value = self.data_stack.pop();
        self.memory[self.registers.b] = value;
    }

    fn store(self: *@This()) void {
        const value = self.data_stack.pop();
        self.memory[self.registers.a] = value;
    }

    // ALU, registers ===
};

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

const DataStack = struct {
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

const ReturnStack = struct {
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

test {
    const vm: VM = undefined;
    _ = vm;
}
