const std_ = @import("std");

const mem = @import("memory.zig");

const kernel = @import("kernel.zig");
const Kernel = kernel.Kernel;
const Cell = kernel.Cell;
const DoubleCell = kernel.DoubleCell;
const SignedCell = kernel.SignedCell;

const writeFile = @import("utils/read-file.zig").writeFile;

// ===

pub const Error = error{
    Panic,
    InvalidProgramCounter,
    OutOfBounds,
    MisalignedAddress,
    CannotAccept,
    CannotEmit,
};

pub const BytecodeFn = *const fn (kernel: *Kernel) Error!void;

pub const callbacks = [_]BytecodeFn{
    &exit,     &docol,    &docon,     &docre,
    &jump,     &jump0,    &lit,       &panic,
    &accept,   &emit,     &eq,        &gt,
    &gteq,     &eq0,      &lt,        &lteq,
    &ugt,      &ugteq,    &ult,       &ulteq,
    &and_,     &or_,      &xor,       &invert,
    &lshift,   &rshift,   &store,     &storeAdd,
    &fetch,    &storeC,   &storeAddC, &fetchC,
    &toR,      &fromR,    &fetchR,    &plus,
    &minus,    &multiply, &divide,    &mod,
    &divmod,   &muldiv,   &muldivmod, &inc,
    &dec,      &negate,   &drop,      &dup,
    &maybeDup, &swap,     &flip,      &over,
    &nip,      &tuck,     &rot,       &nrot,
    &move,     &memEqual, &extId,
};

pub fn getBytecode(token: Cell) ?BytecodeFn {
    if (token < callbacks.len) {
        return callbacks[token];
    } else {
        return null;
    }
}

pub fn docol(k: *Kernel) Error!void {
    k.return_stack.pushCell(k.program_counter.fetch());
    k.program_counter.store(k.current_token_addr.fetch() + @sizeOf(Cell));
}

pub fn docon(k: *Kernel) Error!void {
    const addr = k.current_token_addr.fetch() + @sizeOf(Cell);
    const value = mem.readCell(k.memory, addr) catch unreachable;
    k.data_stack.pushCell(value);
}

pub fn docre(k: *Kernel) Error!void {
    const does_addr = k.current_token_addr.fetch() + @sizeOf(Cell);
    const body_addr = does_addr + @sizeOf(Cell);
    const does = mem.readCell(k.memory, does_addr) catch unreachable;
    k.data_stack.pushCell(body_addr);
    k.return_stack.pushCell(k.program_counter.fetch());
    k.setCfaToExecute(does);
}

pub fn exit(k: *Kernel) Error!void {
    k.program_counter.store(k.return_stack.popCell());
}

pub fn execute(k: *Kernel) Error!void {
    const cfa_addr = k.data_stack.popCell();
    k.return_stack.pushCell(k.program_counter.fetch());
    k.setCfaToExecute(cfa_addr);
}

pub fn jump(k: *Kernel) Error!void {
    try k.assertValidProgramCounter();
    const addr = try mem.readCell(k.memory, k.program_counter.fetch());
    try mem.assertOffsetInBounds(addr, @sizeOf(Cell));
    k.program_counter.store(addr);
}

pub fn jump0(k: *Kernel) Error!void {
    try k.assertValidProgramCounter();

    const conditional = k.data_stack.popCell();
    if (!kernel.isTruthy(conditional)) {
        try jump(k);
    } else {
        try k.advancePC(@sizeOf(Cell));
    }
}

pub fn lit(k: *Kernel) Error!void {
    try k.assertValidProgramCounter();
    const value = try mem.readCell(k.memory, k.program_counter.fetch());
    k.data_stack.pushCell(value);
    try k.advancePC(@sizeOf(Cell));
}

pub fn panic(_: *Kernel) Error!void {
    return error.Panic;
}

pub fn accept(k: *Kernel) Error!void {
    const len = k.data_stack.popCell();
    const addr = k.data_stack.popCell();
    const out = try mem.sliceFromAddrAndLen(
        k.memory,
        addr,
        len,
    );

    if (k.accept_buffer) |*accept_buffer| {
        const reader = accept_buffer.stream.reader();
        const slice =
            reader.readUntilDelimiterOrEof(
                out[0..out.len],
                '\n',
            ) catch |err| {
                // TODO errors
                @import("std").debug.print("{}\n", .{err});
                return error.CannotAccept;
            };
        if (slice) |slc| {
            k.data_stack.pushCell(@truncate(slc.len));
        } else {
            k.clearAcceptBuffer();
            k.data_stack.pushCell(0);
        }
    } else if (k.accept_closure) |closure| {
        const size = try closure.callback(out, closure.userdata);
        k.data_stack.pushCell(size);
    } else {
        return error.CannotAccept;
    }
}

pub fn emit(k: *Kernel) Error!void {
    const raw_char = k.data_stack.popCell();
    const char = @as(u8, @truncate(raw_char & 0xff));

    if (k.emit_closure) |closure| {
        closure.callback(char, closure.userdata);
    } else {
        return error.CannotEmit;
    }
}

pub fn eq(k: *Kernel) Error!void {
    k.data_stack.eq();
}

pub fn eq0(k: *Kernel) Error!void {
    k.data_stack.eq0();
}

pub fn gt(k: *Kernel) Error!void {
    k.data_stack.gt();
}

pub fn gteq(k: *Kernel) Error!void {
    k.data_stack.gteq();
}

pub fn lt(k: *Kernel) Error!void {
    k.data_stack.lt();
}

pub fn lteq(k: *Kernel) Error!void {
    k.data_stack.lteq();
}

pub fn ugt(k: *Kernel) Error!void {
    k.data_stack.ugt();
}

pub fn ugteq(k: *Kernel) Error!void {
    k.data_stack.ugteq();
}

pub fn ult(k: *Kernel) Error!void {
    k.data_stack.ult();
}

pub fn ulteq(k: *Kernel) Error!void {
    k.data_stack.ulteq();
}

pub fn and_(k: *Kernel) Error!void {
    k.data_stack.and_();
}

pub fn or_(k: *Kernel) Error!void {
    k.data_stack.ior();
}

pub fn xor(k: *Kernel) Error!void {
    k.data_stack.xor();
}

pub fn invert(k: *Kernel) Error!void {
    k.data_stack.invert();
}

pub fn lshift(k: *Kernel) Error!void {
    k.data_stack.lshift();
}

pub fn rshift(k: *Kernel) Error!void {
    k.data_stack.rshift();
}

pub fn inc(k: *Kernel) Error!void {
    k.data_stack.inc();
}

pub fn dec(k: *Kernel) Error!void {
    k.data_stack.dec();
}

pub fn negate(k: *Kernel) Error!void {
    const value = k.data_stack.popSignedCell();
    k.data_stack.pushSignedCell(-value);
}

pub fn drop(k: *Kernel) Error!void {
    k.data_stack.drop();
}

pub fn dup(k: *Kernel) Error!void {
    k.data_stack.dup();
}

pub fn maybeDup(k: *Kernel) Error!void {
    const top = k.data_stack.peekCell();
    if (kernel.isTruthy(top)) {
        k.data_stack.dup();
    }
}

pub fn swap(k: *Kernel) Error!void {
    k.data_stack.swap();
}

pub fn flip(k: *Kernel) Error!void {
    k.data_stack.flip();
}

pub fn over(k: *Kernel) Error!void {
    k.data_stack.over();
}

pub fn nip(k: *Kernel) Error!void {
    k.data_stack.nip();
}

pub fn tuck(k: *Kernel) Error!void {
    k.data_stack.tuck();
}

pub fn rot(k: *Kernel) Error!void {
    k.data_stack.rot();
}

pub fn nrot(k: *Kernel) Error!void {
    k.data_stack.nrot();
}

pub fn store(k: *Kernel) Error!void {
    const addr = k.data_stack.popCell();
    const value = k.data_stack.popCell();
    try mem.writeCell(k.memory, addr, value);
}

pub fn storeAdd(k: *Kernel) Error!void {
    const addr = k.data_stack.popCell();
    const value = k.data_stack.popCell();
    (try mem.cellPtr(k.memory, addr)).* +%= value;
}

pub fn fetch(k: *Kernel) Error!void {
    const addr = k.data_stack.popCell();
    k.data_stack.pushCell(try mem.readCell(k.memory, addr));
}

pub fn storeC(k: *Kernel) Error!void {
    const addr = k.data_stack.popCell();
    const value = k.data_stack.popCell();
    const value_u8: u8 = @truncate(value);
    k.memory[addr] = value_u8;
}

pub fn storeAddC(k: *Kernel) Error!void {
    const addr = k.data_stack.popCell();
    const value = k.data_stack.popCell();
    const value_u8: u8 = @truncate(value);
    k.memory[addr] +%= value_u8;
}

pub fn fetchC(k: *Kernel) Error!void {
    const addr = k.data_stack.popCell();
    k.data_stack.pushCell(k.memory[addr]);
}

pub fn toR(k: *Kernel) Error!void {
    k.return_stack.pushCell(k.data_stack.popCell());
}

pub fn fromR(k: *Kernel) Error!void {
    k.data_stack.pushCell(k.return_stack.popCell());
}

pub fn fetchR(k: *Kernel) Error!void {
    k.data_stack.pushCell(k.return_stack.peekCell());
}

pub fn plus(k: *Kernel) Error!void {
    k.data_stack.add();
}

pub fn minus(k: *Kernel) Error!void {
    k.data_stack.subtract();
}

pub fn multiply(k: *Kernel) Error!void {
    k.data_stack.multiply();
}

pub fn divide(k: *Kernel) Error!void {
    k.data_stack.divide();
}

pub fn mod(k: *Kernel) Error!void {
    k.data_stack.mod();
}

// TODO move this into DataStack definiton
pub fn divmod(k: *Kernel) Error!void {
    const div = k.data_stack.popCell();
    const value = k.data_stack.popCell();
    const q = value / div;
    const r = value % div;
    k.data_stack.pushCell(@truncate(q));
    k.data_stack.pushCell(@truncate(r));
}

// TODO move this into DataStack definiton
pub fn muldiv(k: *Kernel) Error!void {
    const div = k.data_stack.popCell();
    const mul = k.data_stack.popCell();
    const value = k.data_stack.popCell();
    const double_value: DoubleCell = @intCast(value);
    const double_mul: DoubleCell = @intCast(mul);
    const calc = double_value * double_mul / div;
    // NOTE
    // truncating
    // this can happen when mul is big and div is small
    k.data_stack.pushCell(@truncate(calc));
}

// TODO move this into DataStack definiton
pub fn muldivmod(k: *Kernel) Error!void {
    const div = k.data_stack.popCell();
    const mul = k.data_stack.popCell();
    const value = k.data_stack.popCell();
    const double_value: DoubleCell = @intCast(value);
    const double_mul: DoubleCell = @intCast(mul);
    const q = double_value * double_mul / div;
    const r = double_value * double_mul % div;
    // NOTE
    // truncating
    // this can happen when mul is big and div is small
    k.data_stack.pushCell(@truncate(q));
    k.data_stack.pushCell(@truncate(r));
}

pub fn move(k: *Kernel) Error!void {
    const std = @import("std");

    const count = k.data_stack.popCell();
    const destination = k.data_stack.popCell();
    const source = k.data_stack.popCell();
    const source_slice = try mem.constSliceFromAddrAndLen(
        k.memory,
        source,
        count,
    );
    const destination_slice = try mem.sliceFromAddrAndLen(
        k.memory,
        destination,
        count,
    );

    if (destination > source) {
        std.mem.copyBackwards(u8, destination_slice, source_slice);
    } else {
        std.mem.copyForwards(u8, destination_slice, source_slice);
    }
}

pub fn memEqual(k: *Kernel) Error!void {
    const std = @import("std");

    const count = k.data_stack.popCell();
    const b_addr = k.data_stack.popCell();
    const a_addr = k.data_stack.popCell();
    const a_slice = try mem.constSliceFromAddrAndLen(
        k.memory,
        a_addr,
        count,
    );
    const b_slice = try mem.constSliceFromAddrAndLen(
        k.memory,
        b_addr,
        count,
    );
    const areEqual = std.mem.eql(u8, a_slice, b_slice);
    k.data_stack.pushCell(kernel.cellFromBoolean(areEqual));
}

pub fn extId(k: *Kernel) Error!void {
    const len = k.data_stack.popCell();
    const addr = k.data_stack.popCell();

    const name = try mem.constSliceFromAddrAndLen(
        k.memory,
        addr,
        len,
    );

    const ext_token = k.lookupExternal(name) orelse 0xffff;
    const token = ext_token + @as(Cell, @intCast(callbacks.len));
    k.data_stack.pushCell(token);
}
