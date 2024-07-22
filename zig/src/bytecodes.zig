const mem = @import("std").mem;

const vm = @import("MiniVM.zig");

fn nop(_: *vm.MiniVM) vm.Error!void {}

const NamedCallback = struct {
    name: []const u8 = "",
    callback: vm.BytecodeFn = nop,
    isImmediate: bool = false,
    needsValidProgramCounter: bool = false,
};

fn bye(mini: *vm.MiniVM) vm.Error!void {
    mini.should_bye = true;
}

fn quit(mini: *vm.MiniVM) vm.Error!void {
    mini.should_quit = true;
}

fn exit(mini: *vm.MiniVM) vm.Error!void {
    const addr = try mini.return_stack.pop();
    try mini.absoluteJump(addr);
}

fn panic(mini: *vm.MiniVM) vm.Error!void {
    // TODO some type of panic message
    mini.should_bye = true;
}

fn branch(_: *vm.MiniVM) vm.Error!void {}
fn branch0(_: *vm.MiniVM) vm.Error!void {}

fn execute(mini: *vm.MiniVM) vm.Error!void {
    const addr = try mini.data_stack.pop();
    try mini.absoluteJump(addr, true);
}

fn tailcall(mini: *vm.MiniVM) vm.Error!void {
    const addr = mini.readCellAndAdvancePC();
    try mini.absoluteJump(addr, false);
}

fn store(mini: *vm.MiniVM) vm.Error!void {
    const addr, const value = try mini.data_stack.popMultiple(2);
    const mem_ptr = mini.memory.cellAt(addr);
    mem_ptr.* = value;
}

fn storeAdd(mini: *vm.MiniVM) vm.Error!void {
    const addr, const value = try mini.data_stack.popMultiple(2);
    const mem_ptr = mini.memory.cellAt(addr);
    mem_ptr.* +%= value;
}

fn fetch(mini: *vm.MiniVM) vm.Error!void {
    const addr = try mini.data_stack.pop();
    const mem_ptr = mini.memory.cellAt(addr);
    try mini.data_stack.push(mem_ptr.*);
}

fn lit(mini: *vm.MiniVM) vm.Error!void {
    const value = mini.readCellAndAdvancePC();
    try mini.data_stack.push(value);
}

fn storeC(mini: *vm.MiniVM) vm.Error!void {
    const addr, const value = try mini.data_stack.popMultiple(2);
    const byte: u8 = @truncate(value);
    mini.memory.byteAt(addr).* = byte;
}

fn storeAddC(mini: *vm.MiniVM) vm.Error!void {
    const addr, const value = try mini.data_stack.popMultiple(2);
    const byte: u8 = @truncate(value);
    mini.memory.byteAt(addr).* +%= byte;
}

fn fetchC(mini: *vm.MiniVM) vm.Error!void {
    const addr = try mini.data_stack.pop();
    try mini.data_stack.push(mini.memory.byteAt(addr).*);
}

fn litC(mini: *vm.MiniVM) vm.Error!void {
    const byte = mini.readByteAndAdvancePC();
    try mini.data_stack.push(byte);
}

fn toR(mini: *vm.MiniVM) vm.Error!void {
    const value = try mini.data_stack.pop();
    mini.return_stack.push(value) catch |err| {
        return vm.returnStackErrorFromStackError(err);
    };
}

fn fromR(mini: *vm.MiniVM) vm.Error!void {
    const value = mini.return_stack.pop() catch |err| {
        return vm.returnStackErrorFromStackError(err);
    };
    try mini.data_stack.push(value);
}

fn Rfetch(mini: *vm.MiniVM) vm.Error!void {
    const value = mini.return_stack.peek() catch |err| {
        return vm.returnStackErrorFromStackError(err);
    };
    try mini.data_stack.push(value);
}

fn eq(mini: *vm.MiniVM) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(vm.fromBool(vm.Cell, a == b));
}

fn lt(mini: *vm.MiniVM) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    // NOTE, the actual operator is '>' because stack order is ( b a )
    try mini.data_stack.push(vm.fromBool(vm.Cell, a > b));
}

fn lteq(mini: *vm.MiniVM) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    // NOTE, the actual operator is '>=' because stack order is ( b a )
    try mini.data_stack.push(vm.fromBool(vm.Cell, a >= b));
}

fn plus(mini: *vm.MiniVM) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(a +% b);
}

fn minus(mini: *vm.MiniVM) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(a -% b);
}

fn multiply(mini: *vm.MiniVM) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(a *% b);
}

fn divMod(mini: *vm.MiniVM) vm.Error!void {
    // TODO
    // not currenly clear wether this bytecode is needed or not
    _ = mini;
}

fn uDivMod(mini: *vm.MiniVM) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    const q = @divTrunc(b, a);
    const mod = @mod(b, a);
    try mini.data_stack.push(mod);
    try mini.data_stack.push(q);
}

fn negate(mini: *vm.MiniVM) vm.Error!void {
    const value = try mini.data_stack.pop();
    _ = value;
    // TODO
    // try mini.data_stack.push(-value);
}

fn lshift(mini: *vm.MiniVM) vm.Error!void {
    const value, const shift_ = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(value << @truncate(shift_));
}

fn rshift(mini: *vm.MiniVM) vm.Error!void {
    const value, const shift_ = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(value >> @truncate(shift_));
}

fn miniAnd(mini: *vm.MiniVM) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(a & b);
}

fn miniOr(mini: *vm.MiniVM) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(a | b);
}

fn xor(mini: *vm.MiniVM) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(a ^ b);
}

fn invert(mini: *vm.MiniVM) vm.Error!void {
    const value = try mini.data_stack.pop();
    try mini.data_stack.push(~value);
}

fn dup(mini: *vm.MiniVM) vm.Error!void {
    try mini.data_stack.dup();
}

fn drop(mini: *vm.MiniVM) vm.Error!void {
    try mini.data_stack.drop();
}

fn swap(mini: *vm.MiniVM) vm.Error!void {
    try mini.data_stack.swap();
}

fn rot(mini: *vm.MiniVM) vm.Error!void {
    try mini.data_stack.rot();
}

fn nrot(mini: *vm.MiniVM) vm.Error!void {
    try mini.data_stack.nrot();
}

fn eq0(mini: *vm.MiniVM) vm.Error!void {
    const value = try mini.data_stack.pop();
    try mini.data_stack.push(vm.fromBool(vm.Cell, value == 0));
}

fn gt(mini: *vm.MiniVM) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    // NOTE, the actual operator is '<' because stack order is ( b a )
    try mini.data_stack.push(vm.fromBool(vm.Cell, a < b));
}

fn gteq(mini: *vm.MiniVM) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    // NOTE, the actual operator is '<=' because stack order is ( b a )
    try mini.data_stack.push(vm.fromBool(vm.Cell, a <= b));
}

fn plus1(mini: *vm.MiniVM) vm.Error!void {
    const value = try mini.data_stack.pop();
    try mini.data_stack.push(value +% 1);
}

fn minus1(mini: *vm.MiniVM) vm.Error!void {
    const value = try mini.data_stack.pop();
    try mini.data_stack.push(value -% 1);
}

fn push0(mini: *vm.MiniVM) vm.Error!void {
    try mini.data_stack.push(0);
}

fn pushFFFF(mini: *vm.MiniVM) vm.Error!void {
    try mini.data_stack.push(0xFFFF);
}

fn push1(mini: *vm.MiniVM) vm.Error!void {
    try mini.data_stack.push(1);
}

fn push2(mini: *vm.MiniVM) vm.Error!void {
    try mini.data_stack.push(2);
}

fn push4(mini: *vm.MiniVM) vm.Error!void {
    try mini.data_stack.push(4);
}

fn push8(mini: *vm.MiniVM) vm.Error!void {
    try mini.data_stack.push(8);
}

fn cellToBytes(mini: *vm.MiniVM) vm.Error!void {
    // TODO
    // instead of doing all this, could potentially just
    //   manipulate stack memory as bytes
    const value = try mini.data_stack.pop();
    const low = @as(u8, @truncate(value));
    const high = @as(u8, @truncate(value >> 8));
    try mini.data_stack.push(low);
    try mini.data_stack.push(high);
}

fn bytesToCell(mini: *vm.MiniVM) vm.Error!void {
    // TODO
    // instead of doing all this, could potentially just
    //   manipulate stack memory as bytes
    const high, const low = try mini.data_stack.popMultiple(2);
    const low_byte = @as(u8, @truncate(low));
    const high_byte = @as(u8, @truncate(high));
    const value = low_byte | (@as(vm.Cell, high_byte) << 8);
    try mini.data_stack.push(value);
}

fn cmove(mini: *vm.MiniVM) vm.Error!void {
    _ = mini;
    // TODO
    // mem.copyForwards()
}

fn cmoveUp(mini: *vm.MiniVM) vm.Error!void {
    _ = mini;
    // TODO
    // mem.copyBackwards()
}

fn memEq(mini: *vm.MiniVM) vm.Error!void {
    _ = mini;
    // TODO
    // mem.eql
}

fn maybeDup(mini: *vm.MiniVM) vm.Error!void {
    const condition = try mini.data_stack.pop();
    if (vm.isTruthy(condition)) {
        try dup(mini);
    }
}

fn nip(mini: *vm.MiniVM) vm.Error!void {
    try mini.data_stack.nip();
}

fn flip(mini: *vm.MiniVM) vm.Error!void {
    try mini.data_stack.flip();
}

fn tuck(mini: *vm.MiniVM) vm.Error!void {
    try mini.data_stack.tuck();
}

fn over(mini: *vm.MiniVM) vm.Error!void {
    try mini.data_stack.over();
}

const lookup_table = [_]NamedCallback{
    // ===
    .{ .name = "bye", .callback = bye },
    .{ .name = "quit", .callback = quit },
    .{ .name = "exit", .callback = exit },
    .{ .name = "panic", .callback = panic },

    // TODO
    .{ .name = "'", .callback = nop },
    .{ .name = "[']", .callback = nop, .isImmediate = true },
    .{ .name = "]", .callback = nop, .isImmediate = true },
    .{ .name = "[", .callback = nop },

    // TODO
    .{ .name = "find", .callback = nop },
    .{ .name = "word", .callback = nop },
    .{ .name = "next-char", .callback = nop },
    .{ .name = "define", .callback = nop },

    // TODO
    .{ .name = "branch", .callback = branch, .needsValidProgramCounter = true },
    .{ .name = "branch0", .callback = branch0, .needsValidProgramCounter = true },
    .{ .name = "execute", .callback = execute, .needsValidProgramCounter = true },
    .{ .name = "tailcall", .callback = tailcall, .needsValidProgramCounter = true },

    // ===
    .{ .name = "!", .callback = store },
    .{ .name = "+!", .callback = storeAdd },
    .{ .name = "@", .callback = fetch },
    // TODO
    .{ .name = ",", .callback = nop },
    .{ .name = "lit", .callback = lit, .needsValidProgramCounter = true },

    .{ .name = "c!", .callback = storeC },
    .{ .name = "+c!", .callback = storeAddC },
    .{ .name = "c@", .callback = fetchC },
    // TODO
    .{ .name = "c,", .callback = nop },
    .{ .name = "litc", .callback = litC, .needsValidProgramCounter = true },

    .{ .name = ">r", .callback = toR },
    .{ .name = "r>", .callback = fromR },
    .{ .name = "r@", .callback = Rfetch },

    .{ .name = "=", .callback = eq },
    .{ .name = "<", .callback = lt },
    .{ .name = "<=", .callback = lteq },

    // ===
    .{ .name = "+", .callback = plus },
    .{ .name = "-", .callback = minus },
    .{ .name = "*", .callback = multiply },
    .{ .name = "/mod", .callback = divMod },
    .{ .name = "u/mod", .callback = uDivMod },
    .{ .name = "negate", .callback = negate },

    .{ .name = "lshift", .callback = lshift },
    .{ .name = "rshift", .callback = rshift },
    .{ .name = "and", .callback = miniAnd },
    .{ .name = "or", .callback = miniOr },
    .{ .name = "xor", .callback = xor },
    .{ .name = "invert", .callback = invert },

    // TODO
    .{ .name = "seldev", .callback = nop },
    .{ .name = "d!", .callback = nop },
    .{ .name = "d+!", .callback = nop },
    .{ .name = "d@", .callback = nop },

    // ===
    .{ .name = "dup", .callback = dup },
    .{ .name = "drop", .callback = drop },
    .{ .name = "swap", .callback = swap },
    .{ .name = "pick", .callback = nop },

    .{ .name = "rot", .callback = rot },
    .{ .name = "-rot", .callback = nrot },
    .{},
    .{},

    .{},
    .{},
    .{},
    .{},

    .{},
    .{},
    .{},
    .{},

    // ===
    .{ .name = "0=", .callback = eq0 },
    .{ .name = ">", .callback = gt },
    .{ .name = ">=", .callback = gteq },

    // TODO
    .{ .name = "here!", .callback = nop },
    .{ .name = "here+!", .callback = nop },
    .{ .name = "here@", .callback = nop },

    .{ .name = "1+", .callback = plus1 },
    .{ .name = "1-", .callback = minus1 },

    .{ .name = "0", .callback = push0 },
    .{ .name = "0xffff", .callback = pushFFFF },

    .{ .name = "1", .callback = push1 },
    .{ .name = "2", .callback = push2 },
    .{ .name = "4", .callback = push4 },
    .{ .name = "8", .callback = push8 },

    .{ .name = "cell>bytes", .callback = cellToBytes },
    .{ .name = "bytes>cell", .callback = bytesToCell },

    // ===
    .{ .name = "cmove", .callback = cmove },
    .{ .name = "cmove>", .callback = cmoveUp },
    .{ .name = "mem=", .callback = memEq },

    .{ .name = "?dup", .callback = maybeDup },

    .{ .name = "nip", .callback = nip },
    .{ .name = "flip", .callback = flip },
    .{ .name = "tuck", .callback = tuck },
    .{ .name = "over", .callback = over },

    .{},
    .{},
    .{},
    .{},

    .{},
    .{},
    .{},
    .{},

    // ===
    .{},
    .{},
    .{},
    .{},

    .{},
    .{},
    .{},
    .{},

    .{},
    .{},
    .{},
    .{},

    .{},
    .{},
    .{},
    .{},
};

pub fn getCallbackById(id: u8) NamedCallback {
    return lookup_table[id];
}

// pub fn getCallbackByName(name: []u8) ?struct { ncb: NamedCallback, index: usize } {
// for (lookup_table, 0..) |named_callback, i| {
// const eql = mem.eql(named_callback.name, name);
// if (eql) {
// return .{ .named_callback = named_callback, .index = i };
// }
// }
// return null;
// }

pub fn getCallbackBytecode(name: []const u8) ?u8 {
    for (lookup_table, 0..) |named_callback, i| {
        const eql = mem.eql(u8, named_callback.name, name);
        if (eql) {
            return @truncate(i);
        }
    }
    return null;
}
