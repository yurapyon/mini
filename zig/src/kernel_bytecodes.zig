const std_ = @import("std");

const mem = @import("memory.zig");

const stringsEqual = @import("utils/strings-equal.zig").stringsEqual;

const runtime = @import("runtime.zig");
const Runtime = runtime.Runtime;
const Cell = runtime.Cell;
const DoubleCell = runtime.DoubleCell;
const SignedCell = runtime.SignedCell;

// ===

pub const Error = error{
    Panic,
    InvalidProgramCounter,
    WordNameTooLong,
    InvalidWordlist,
    OutOfBounds,
    MisalignedAddress,
    UnexpectedEndOfInput,
    CannotRefill,
    OversizeInputBuffer,
    WordNotFound,
    InvalidCompileState,
};

pub const BytecodeFn = *const fn (runtime: *Runtime) Error!void;

pub const callbacks = [_]BytecodeFn{
    &exit,
    &panic,
    // &abort,
    &quit,
    &execute,
    &refill,
    &docol,
    // ...
};

pub fn getBytecode(token: Cell) ?BytecodeFn {
    if (token < callbacks.len) {
        return callbacks[token];
    } else {
        return null;
    }
}

pub fn docol(rt: *Runtime) Error!void {
    rt.return_stack.pushCell(rt.program_counter);
    rt.program_counter = rt.current_token_addr + @sizeOf(Cell);
}

pub fn docon(rt: *Runtime) Error!void {
    const addr = rt.current_token_addr + @sizeOf(Cell);
    const value = mem.readCell(rt.memory, addr) catch unreachable;
    rt.data_stack.pushCell(value);
}

pub fn docre(rt: *Runtime) Error!void {
    const does_addr = rt.current_token_addr + @sizeOf(Cell);
    const body_addr = does_addr + @sizeOf(Cell);
    const does = mem.readCell(rt.memory, does_addr) catch unreachable;
    rt.data_stack.pushCell(body_addr);
    rt.return_stack.pushCell(rt.program_counter);
    rt.setCfaToExecute(does);
}

pub fn panic(_: *Runtime) Error!void {
    return error.Panic;
}

pub fn exit(rt: *Runtime) Error!void {
    rt.program_counter = rt.return_stack.popCell();
}

pub fn execute(rt: *Runtime) Error!void {
    const cfa_addr = rt.data_stack.popCell();
    rt.return_stack.pushCell(rt.program_counter);
    rt.setCfaToExecute(cfa_addr);
}

pub fn jump(rt: *Runtime) Error!void {
    try rt.assertValidProgramCounter();
    const addr = try mem.readCell(rt.memory, rt.program_counter);
    try mem.assertOffsetInBounds(addr, @sizeOf(Cell));
    rt.program_counter = addr;
}

pub fn jump0(rt: *Runtime) Error!void {
    try rt.assertValidProgramCounter();

    const conditional = rt.data_stack.popCell();
    if (!runtime.isTruthy(conditional)) {
        try jump(rt);
    } else {
        try rt.advancePC(@sizeOf(Cell));
    }
}

pub fn quit(rt: *Runtime) Error!void {
    // TODO this needs to clear the return stack, now that its not circular
    rt.program_counter = 0;
    rt.should_quit = true;
}

pub fn eq(rt: *Runtime) Error!void {
    rt.data_stack.eq();
}

pub fn eq0(rt: *Runtime) Error!void {
    rt.data_stack.eq0();
}

pub fn gt(rt: *Runtime) Error!void {
    rt.data_stack.gt();
}

pub fn gteq(rt: *Runtime) Error!void {
    rt.data_stack.gteq();
}

pub fn lt(rt: *Runtime) Error!void {
    rt.data_stack.lt();
}

pub fn lteq(rt: *Runtime) Error!void {
    rt.data_stack.lteq();
}

pub fn ugt(rt: *Runtime) Error!void {
    rt.data_stack.ugt();
}

pub fn ugteq(rt: *Runtime) Error!void {
    rt.data_stack.ugteq();
}

pub fn ult(rt: *Runtime) Error!void {
    rt.data_stack.ult();
}

pub fn ulteq(rt: *Runtime) Error!void {
    rt.data_stack.ulteq();
}

pub fn and_(rt: *Runtime) Error!void {
    rt.data_stack.and_();
}

pub fn or_(rt: *Runtime) Error!void {
    rt.data_stack.ior();
}

pub fn xor(rt: *Runtime) Error!void {
    rt.data_stack.xor();
}

pub fn invert(rt: *Runtime) Error!void {
    rt.data_stack.invert();
}

pub fn lshift(rt: *Runtime) Error!void {
    rt.data_stack.lshift();
}

pub fn rshift(rt: *Runtime) Error!void {
    rt.data_stack.rshift();
}

pub fn inc(rt: *Runtime) Error!void {
    rt.data_stack.inc();
}

pub fn dec(rt: *Runtime) Error!void {
    rt.data_stack.dec();
}

pub fn drop(rt: *Runtime) Error!void {
    rt.data_stack.drop();
}

pub fn dup(rt: *Runtime) Error!void {
    rt.data_stack.dup();
}

pub fn maybeDup(rt: *Runtime) Error!void {
    const top = rt.data_stack.peekCell();
    if (runtime.isTruthy(top)) {
        rt.data_stack.dup();
    }
}

pub fn swap(rt: *Runtime) Error!void {
    rt.data_stack.swap();
}

pub fn flip(rt: *Runtime) Error!void {
    rt.data_stack.flip();
}

pub fn over(rt: *Runtime) Error!void {
    rt.data_stack.over();
}

pub fn nip(rt: *Runtime) Error!void {
    rt.data_stack.nip();
}

pub fn tuck(rt: *Runtime) Error!void {
    rt.data_stack.tuck();
}

pub fn rot(rt: *Runtime) Error!void {
    rt.data_stack.rot();
}

pub fn nrot(rt: *Runtime) Error!void {
    rt.data_stack.nrot();
}

pub fn store(rt: *Runtime) Error!void {
    const addr = rt.data_stack.popCell();
    const value = rt.data_stack.popCell();
    try mem.writeCell(rt.memory, addr, value);
}

pub fn fetchAdd(rt: *Runtime) Error!void {
    const addr = rt.data_stack.popCell();
    const value = rt.data_stack.popCell();
    (try mem.cellPtr(rt.memory, addr)).* +%= value;
}

pub fn fetch(rt: *Runtime) Error!void {
    const addr = rt.data_stack.popCell();
    rt.data_stack.pushCell(try mem.readCell(rt.memory, addr));
}

pub fn comma(rt: *Runtime) Error!void {
    const value = rt.data_stack.popCell();
    try rt.interpreter.dictionary.here.comma(value);
}

pub fn storeC(rt: *Runtime) Error!void {
    const addr = rt.data_stack.popCell();
    const value = rt.data_stack.popCell();
    const value_u8: u8 = @truncate(value);
    rt.memory[addr] = value_u8;
}

pub fn fetchAddC(rt: *Runtime) Error!void {
    const addr = rt.data_stack.popCell();
    const value = rt.data_stack.popCell();
    const value_u8: u8 = @truncate(value);
    rt.memory[addr] +%= value_u8;
}

pub fn fetchC(rt: *Runtime) Error!void {
    const addr = rt.data_stack.popCell();
    rt.data_stack.pushCell(rt.memory[addr]);
}

pub fn commaC(rt: *Runtime) Error!void {
    const value = rt.data_stack.popCell();
    try rt.interpreter.dictionary.here.commaC(@truncate(value));
}

pub fn toR(rt: *Runtime) Error!void {
    rt.return_stack.pushCell(rt.data_stack.popCell());
}

pub fn fromR(rt: *Runtime) Error!void {
    rt.data_stack.pushCell(rt.return_stack.popCell());
}

pub fn fetchR(rt: *Runtime) Error!void {
    rt.data_stack.pushCell(rt.return_stack.peekCell());
}

pub fn plus(rt: *Runtime) Error!void {
    rt.data_stack.add();
}

pub fn minus(rt: *Runtime) Error!void {
    rt.data_stack.subtract();
}

pub fn multiply(rt: *Runtime) Error!void {
    rt.data_stack.multiply();
}

pub fn divide(rt: *Runtime) Error!void {
    rt.data_stack.divide();
}

pub fn mod(rt: *Runtime) Error!void {
    rt.data_stack.mod();
}

// TODO move this into DataStack definiton
pub fn divmod(rt: *Runtime) Error!void {
    const div = rt.data_stack.popCell();
    const value = rt.data_stack.popCell();
    const q = value / div;
    const r = value % div;
    rt.data_stack.pushCell(@truncate(q));
    rt.data_stack.pushCell(@truncate(r));
}

// TODO move this into DataStack definiton
pub fn muldiv(rt: *Runtime) Error!void {
    const div = rt.data_stack.popCell();
    const mul = rt.data_stack.popCell();
    const value = rt.data_stack.popCell();
    const double_value: DoubleCell = @intCast(value);
    const double_mul: DoubleCell = @intCast(mul);
    const calc = double_value * double_mul / div;
    // NOTE
    // truncating
    // this can happen when mul is big and div is small
    rt.data_stack.pushCell(@truncate(calc));
}

// TODO move this into DataStack definiton
pub fn muldivmod(rt: *Runtime) Error!void {
    const div = rt.data_stack.popCell();
    const mul = rt.data_stack.popCell();
    const value = rt.data_stack.popCell();
    const double_value: DoubleCell = @intCast(value);
    const double_mul: DoubleCell = @intCast(mul);
    const q = double_value * double_mul / div;
    const r = double_value * double_mul % div;
    // NOTE
    // truncating
    // this can happen when mul is big and div is small
    rt.data_stack.pushCell(@truncate(q));
    rt.data_stack.pushCell(@truncate(r));
}

pub fn refill(rt: *Runtime) Error!void {
    const did_refill = try rt.input_buffer.refill();
    // TODO use pushBoolean
    rt.data_stack.pushCell(runtime.cellFromBoolean(did_refill));
}

pub fn lit(rt: *Runtime) Error!void {
    try rt.assertValidProgramCounter();
    const value = try mem.readCell(rt.memory, rt.program_counter);
    rt.data_stack.pushCell(value);
    try rt.advancePC(@sizeOf(Cell));
}
