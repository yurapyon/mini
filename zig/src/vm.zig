const runtime = @import("runtime.zig");
const mem = runtime.mem;
const Cell = runtime.Cell;
const Memory = runtime.Memory;

const stack = @import("stack.zig");

pub const Error = error{
    Panic,
} || mem.Error;

pub const BytecodeFn = *const fn (vm: *VM) Error!void;

/// A 16bit hosted version of the F18
/// By design, this VM can never access out-of-bounds memory
///   there can still be alignment errors though
pub const VM = struct {
    data_stack: stack.DataStack,
    return_stack: stack.ReturnStack,
    registers: struct {
        p: Cell,
        a: Cell,
    },
    memory: *Memory,

    // program control ===

    fn panic(_: *VM) Error!void {
        return error.Panic;
    }

    fn nop(_: *@This()) Error!void {}

    fn exit(self: *@This()) Error!void {
        self.registers.p = self.return_stack.pop();
    }

    fn execute(self: *@This()) Error!void {
        const temp = self.return_stack.top;
        self.return_stack.top = self.registers.p;
        self.registers.p = temp;
    }

    // memory ===

    fn fetchByPPlus(self: *@This()) Error!void {
        const value = try mem.readCell(self.memory, self.registers.p);
        self.data_stack.push(value);
        self.registers.p += @sizeOf(Cell);
    }

    fn fetchByAPlus(self: *@This()) Error!void {
        try self.fetchByA();
        self.registers.a += @sizeOf(Cell);
    }

    fn fetchByA(self: *@This()) Error!void {
        const value = try mem.readCell(self.memory, self.registers.a);
        self.data_stack.push(value);
    }

    fn storeByPPlus(self: *@This()) Error!void {
        const value = self.data_stack.pop();
        try mem.writeCell(self.memory, self.registers.p, value);
        self.registers.p += @sizeOf(Cell);
    }

    fn storeByAPlus(self: *@This()) Error!void {
        try self.storeByA();
        self.registers.a += @sizeOf(Cell);
    }

    fn storeByA(self: *@This()) Error!void {
        const value = self.data_stack.pop();
        try mem.writeCell(self.memory, self.registers.a, value);
    }

    fn fetchA(self: *@This()) Error!void {
        self.data_stack.push(self.registers.a);
    }

    fn storeA(self: *@This()) Error!void {
        self.registers.a = self.data_stack.pop();
    }

    // ALU, registers ===

    fn eq(self: *@This()) Error!void {
        self.data_stack.eq();
    }

    fn gt(self: *@This()) Error!void {
        self.data_stack.gt();
    }

    fn gteq(self: *@This()) Error!void {
        self.data_stack.gteq();
    }

    fn and_(self: *@This()) Error!void {
        self.data_stack.and_();
    }

    fn ior(self: *@This()) Error!void {
        self.data_stack.ior();
    }

    fn xor(self: *@This()) Error!void {
        self.data_stack.xor();
    }

    fn invert(self: *@This()) Error!void {
        self.data_stack.invert();
    }

    fn lshift(self: *@This()) Error!void {
        self.data_stack.lshift();
    }

    fn rshift(self: *@This()) Error!void {
        self.data_stack.rshift();
    }

    fn inc(self: *@This()) Error!void {
        self.data_stack.inc();
    }

    fn dec(self: *@This()) Error!void {
        self.data_stack.dec();
    }

    fn drop(self: *@This()) Error!void {
        self.data_stack.drop();
    }

    fn dup(self: *@This()) Error!void {
        self.data_stack.dup();
    }

    fn swap(self: *@This()) Error!void {
        self.data_stack.swap();
    }

    fn flip(self: *@This()) Error!void {
        self.data_stack.flip();
    }

    fn over(self: *@This()) Error!void {
        self.data_stack.over();
    }
};

pub fn getBytecodeFn(byte: u8) ?BytecodeFn {
    if (byte > 64) {
        return null;
    } else {
        return bytecodes[byte];
    }
}

const bytecodes = [64]BytecodeFn{
    VM.nop,
    VM.execute,
    VM.exit,
    VM.eq,
    VM.gt,
    VM.gteq,
    VM.and_,
    VM.ior,
    VM.xor,
    VM.invert,
    VM.lshift,
    VM.rshift,
    VM.inc,
    VM.dec,

    VM.storeByA,
    VM.fetchByA,
    VM.fetchByAPlus,

    VM.storeByPPlus,
    VM.fetchByPPlus,

    VM.drop,
    VM.dup,
    VM.swap,
    VM.flip,
    VM.over,

    VM.panic,
    VM.panic,
    VM.panic,
    VM.panic,
    VM.panic,
    VM.panic,
    VM.panic,
    VM.panic,
    VM.panic,
    VM.panic,
    VM.panic,
    VM.panic,
    VM.panic,
    VM.panic,
    VM.panic,
    VM.panic,
};

test "vm" {
    const vm: VM = undefined;
    _ = vm;
}
