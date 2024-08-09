const runtime = @import("runtime.zig");
const mem = runtime.mem;
const Cell = runtime.Cell;
const Memory = runtime.Memory;

const stack = @import("stack.zig");

pub const Error = error{
    Panic,
    ExternalPanic,
};

/// A 16bit hosted version of the F18
/// By design, this VM can never access out-of-bounds memory
///   there can still be alignment errors though
pub const VM = struct {
    data_stack: stack.DataStack,
    return_stack: stack.ReturnStack,
    registers: struct {
        p: Cell,
        a: Cell,
        b: Cell,
    },
    memory: *Memory,

    // program control ===

    fn nop(_: *@This()) void {}

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

    fn fetchP(self: *@This()) mem.Error!void {
        const value = try mem.readCell(self.memory, self.registers.p);
        self.data_stack.push(value);
        self.registers.p += @sizeOf(Cell);
    }

    fn fetchPlus(self: *@This()) mem.Error!void {
        try self.fetch();
        self.registers.a += @sizeOf(Cell);
    }

    fn fetchB(self: *@This()) mem.Error!void {
        const value = try mem.readCell(self.memory, self.registers.b);
        self.data_stack.push(value);
    }

    fn fetch(self: *@This()) mem.Error!void {
        const value = try mem.readCell(self.memory, self.registers.a);
        self.data_stack.push(value);
    }

    fn storeP(self: *@This()) mem.Error!void {
        const value = self.data_stack.pop();
        try mem.writeCell(self.memory, self.registers.p, value);
        self.registers.p += @sizeOf(Cell);
    }

    fn storePlus(self: *@This()) mem.Error!void {
        try self.store();
        self.registers.a += @sizeOf(Cell);
    }

    fn storeB(self: *@This()) mem.Error!void {
        const value = self.data_stack.pop();
        try mem.writeCell(self.memory, self.registers.b, value);
    }

    fn store(self: *@This()) mem.Error!void {
        const value = self.data_stack.pop();
        try mem.writeCell(self.memory, self.registers.a, value);
    }

    // ALU, registers ===

    // external ===

    fn external(self: *@This()) Error!void {
        // TODO
        _ = self;
    }
};

test {
    const vm: VM = undefined;
    _ = vm;
}
