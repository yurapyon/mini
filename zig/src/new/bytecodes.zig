const runtime = @import("runtime.zig");
const Mini = runtime.Mini;
const Cell = runtime.Cell;
const Error = runtime.Error;
const BytecodeFn = runtime.BytecodeFn;

pub fn getBytecodeFn(byte: u8) ?BytecodeFn {
    if (byte > 64) {
        return null;
    } else {
        return bytecodes[byte];
    }
}

const bytecodes = [64]BytecodeFn{
    nop,
    execute,
    exit,
    eq,
    gt,
    gteq,
    and_,
    ior,
    xor,
    invert,

    panic,
    panic,
    panic,
    panic,
    panic,
    panic,
    panic,
    panic,
    panic,
    panic,
    panic,
    panic,
    panic,
    panic,
    panic,
    panic,
};

fn panic(_: *Mini) Error!void {
    return error.Panic;
}

fn nop(_: *Mini) Error!void {}

fn execute(mini: *Mini) Error!void {
    const temp = mini.vm.return_stack.top;
    mini.vm.return_stack.top = mini.vm.registers.p;
    mini.vm.registers.p = temp;
}

fn exit(mini: *Mini) Error!void {
    mini.vm.registers.p = mini.vm.return_stack.pop();
}

fn eq(mini: *Mini) Error!void {
    mini.vm.data_stack.eq();
}

fn gt(mini: *Mini) Error!void {
    mini.vm.data_stack.gt();
}

fn gteq(mini: *Mini) Error!void {
    mini.vm.data_stack.gteq();
}

fn and_(mini: *Mini) Error!void {
    mini.vm.data_stack.and_();
}

fn ior(mini: *Mini) Error!void {
    mini.vm.data_stack.ior();
}

fn xor(mini: *Mini) Error!void {
    mini.vm.data_stack.xor();
}

fn invert(mini: *Mini) Error!void {
    mini.vm.data_stack.invert();
}
