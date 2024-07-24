const mem = @import("std").mem;

const vm = @import("MiniVM.zig");

// ===

const BytecodeType = enum {
    basic,
    data,
    absolute_jump,
};

pub fn determineType(bytecode: u8) BytecodeType {
    return switch (bytecode) {
        inline 0b00000000...0b01101111 => .basic,
        inline 0b01110000...0b01111111 => .data,
        inline 0b10000000...0b11111111 => .absolute_jump,
    };
}

const BytecodeDefinition = struct {
    name: []const u8 = "",
    callback: vm.BytecodeFn = nop,
    isImmediate: bool = false,
    bytecode_type: BytecodeType = .basic,
};

fn data(mini: *vm.MiniVM, ctx: vm.ExecutionContext) vm.Error!void {
    if (!ctx.program_counter_is_valid) {
        return error.InvalidProgramCounter;
    }

    // TODO verify this works
    // TODO how should endianness be handled for this
    const high = ctx.last_bytecode & 0x0f;
    const low = mini.readByteAndAdvancePC();
    const addr = mini.program_counter.fetch();
    const length = @as(vm.Cell, high) << 8 | low;
    try mini.data_stack.push(addr);
    try mini.data_stack.push(length);
    mini.program_counter.storeAdd(length);
}

const dataDefinition = BytecodeDefinition{
    .name = "data",
    .callback = data,
    .isImmediate = false,
    .bytecode_type = .data,
};

fn absjump(mini: *vm.MiniVM, ctx: vm.ExecutionContext) vm.Error!void {
    if (!ctx.program_counter_is_valid) {
        return error.InvalidProgramCounter;
    }

    // TODO verify this works
    // TODO how should endianness be handled for this
    const high = ctx.last_bytecode & 0x7f;
    const low = mini.readByteAndAdvancePC();
    const addr = @as(vm.Cell, high) << 8 | low;
    try mini.absoluteJump(addr, true);
}

const absJumpDefinition = BytecodeDefinition{
    .name = "absjump",
    .callback = absjump,
    .isImmediate = false,
    .bytecode_type = .absolute_jump,
};

pub fn getBytecodeDefinition(bytecode: u8) BytecodeDefinition {
    return switch (bytecode) {
        inline 0b00000000...0b01101111 => |byte| {
            const id = byte & 0x7f;
            return lookup_table[id];
        },
        inline 0b01110000...0b01111111 => dataDefinition,
        inline 0b10000000...0b11111111 => absJumpDefinition,
    };
}

pub fn executeBytecode(
    bytecode: u8,
    mini: *vm.MiniVM,
    program_counter_is_valid: bool,
) vm.Error!void {
    // Note
    // constructing the execution context in here to hopefully help
    // zig with turning this switch statement into a fancy jump table thing
    // TODO veryify this is compiling how we want it to
    // off the top of my head i think it might not be...
    // the execution context stuff is a little confusing
    switch (bytecode) {
        inline 0b00000000...0b01101111 => |byte| {
            const ctx: vm.ExecutionContext = .{
                .last_bytecode = byte,
                .program_counter_is_valid = program_counter_is_valid,
            };
            const id = byte & 0x7f;
            try lookup_table[id].callback(mini, ctx);
        },
        inline 0b01110000...0b01111111 => |byte| {
            const ctx: vm.ExecutionContext = .{
                .last_bytecode = byte,
                .program_counter_is_valid = program_counter_is_valid,
            };
            try dataDefinition.callback(mini, ctx);
        },
        inline 0b10000000...0b11111111 => |byte| {
            const ctx: vm.ExecutionContext = .{
                .last_bytecode = byte,
                .program_counter_is_valid = program_counter_is_valid,
            };
            try absJumpDefinition.callback(mini, ctx);
        },
    }
}

pub fn lookupBytecodeByName(name: []const u8) ?u8 {
    for (lookup_table, 0..) |named_callback, i| {
        const eql = mem.eql(u8, named_callback.name, name);
        if (eql) {
            return @truncate(i);
        }
    }

    return null;
}

// ===

const lookup_table = [_]BytecodeDefinition{
    // ===
    .{ .name = "bye", .callback = bye },
    .{ .name = "quit", .callback = quit },
    .{ .name = "exit", .callback = exit },
    .{ .name = "panic", .callback = panic },

    .{ .name = "'", .callback = tick },
    .{ .name = "[']", .callback = bracketTick, .isImmediate = true },
    .{ .name = "]", .callback = rBracket, .isImmediate = true },
    .{ .name = "[", .callback = lBracket },

    .{ .name = "find", .callback = find },
    .{ .name = "word", .callback = word },
    .{ .name = "next-char", .callback = nextChar },
    .{ .name = "define", .callback = define },

    .{ .name = "branch", .callback = branch },
    .{ .name = "branch0", .callback = branch0 },
    .{ .name = "execute", .callback = execute },
    .{ .name = "tailcall", .callback = tailcall },

    // ===
    .{ .name = "!", .callback = store },
    .{ .name = "+!", .callback = storeAdd },
    .{ .name = "@", .callback = fetch },
    .{ .name = ",", .callback = comma },
    .{ .name = "lit", .callback = lit },

    .{ .name = "c!", .callback = storeC },
    .{ .name = "+c!", .callback = storeAddC },
    .{ .name = "c@", .callback = fetchC },
    .{ .name = "c,", .callback = commaC },
    .{ .name = "litc", .callback = litC },

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

    .{ .name = "seldev", .callback = selDev },
    .{ .name = "d!", .callback = storeD },
    .{ .name = "d+!", .callback = storeAddD },
    .{ .name = "d@", .callback = fetchD },

    // ===
    .{ .name = "dup", .callback = dup },
    .{ .name = "drop", .callback = drop },
    .{ .name = "swap", .callback = swap },
    .{ .name = "pick", .callback = pick },

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

    .{ .name = "here!", .callback = storeHere },
    .{ .name = "here+!", .callback = storeAddHere },
    .{ .name = "here@", .callback = fetchHere },

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

// ===

fn nop(_: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {}

fn bye(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    mini.should_bye = true;
}

fn quit(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    mini.should_quit = true;
}

fn exit(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const addr = try mini.return_stack.pop();
    try mini.absoluteJump(addr, false);
}

fn panic(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    // TODO some type of panic message
    mini.should_bye = true;
}

fn tick(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    // TODO
    _ = mini;
}

fn bracketTick(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    // TODO
    _ = mini;
}

fn rBracket(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    mini.state.store(@intFromEnum(vm.CompileState.interpret));
}

fn lBracket(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    mini.state.store(@intFromEnum(vm.CompileState.compile));
}

fn branch(mini: *vm.MiniVM, ctx: vm.ExecutionContext) vm.Error!void {
    if (!ctx.program_counter_is_valid) {
        return error.InvalidProgramCounter;
    }

    const addr = mini.readByteAndAdvancePC();
    try mini.absoluteJump(addr, false);
}

fn branch0(mini: *vm.MiniVM, ctx: vm.ExecutionContext) vm.Error!void {
    const condition = try mini.data_stack.pop();
    if (!vm.isTruthy(condition)) {
        return try branch(mini, ctx);
    }
}

fn find(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    // TODO
    _ = mini;
}

fn word(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    // TODO
    _ = mini;
}

fn nextChar(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    // TODO
    _ = mini;
}

fn define(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    // TODO
    try mini.defineWordHeader("");
}

fn execute(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const addr = try mini.data_stack.pop();
    try mini.absoluteJump(addr, true);
}

fn tailcall(mini: *vm.MiniVM, ctx: vm.ExecutionContext) vm.Error!void {
    if (!ctx.program_counter_is_valid) {
        return error.InvalidProgramCounter;
    }

    const addr = mini.readCellAndAdvancePC();
    try mini.absoluteJump(addr, false);
}

fn store(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const addr, const value = try mini.data_stack.popMultiple(2);
    const mem_ptr = vm.cellAt(mini.memory, addr);
    mem_ptr.* = value;
}

fn storeAdd(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const addr, const value = try mini.data_stack.popMultiple(2);
    const mem_ptr = vm.cellAt(mini.memory, addr);
    mem_ptr.* +%= value;
}

fn fetch(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const addr = try mini.data_stack.pop();
    const mem_ptr = vm.cellAt(mini.memory, addr);
    try mini.data_stack.push(mem_ptr.*);
}

fn comma(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const value = try mini.data_stack.pop();
    mini.here.comma(value);
}

fn lit(mini: *vm.MiniVM, ctx: vm.ExecutionContext) vm.Error!void {
    if (!ctx.program_counter_is_valid) {
        return error.InvalidProgramCounter;
    }

    const value = mini.readCellAndAdvancePC();
    try mini.data_stack.push(value);
}

fn storeC(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const addr, const value = try mini.data_stack.popMultiple(2);
    const byte: u8 = @truncate(value);
    mini.memory[addr] = byte;
}

fn storeAddC(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const addr, const value = try mini.data_stack.popMultiple(2);
    const byte: u8 = @truncate(value);
    mini.memory[addr] +%= byte;
}

fn fetchC(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const addr = try mini.data_stack.pop();
    try mini.data_stack.push(mini.memory[addr]);
}

fn commaC(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const value = try mini.data_stack.pop();
    mini.here.commaC(@truncate(value));
}

fn litC(mini: *vm.MiniVM, ctx: vm.ExecutionContext) vm.Error!void {
    if (!ctx.program_counter_is_valid) {
        return error.InvalidProgramCounter;
    }

    const byte = mini.readByteAndAdvancePC();
    try mini.data_stack.push(byte);
}

fn toR(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const value = try mini.data_stack.pop();
    mini.return_stack.push(value) catch |err| {
        return vm.returnStackErrorFromStackError(err);
    };
}

fn fromR(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const value = mini.return_stack.pop() catch |err| {
        return vm.returnStackErrorFromStackError(err);
    };
    try mini.data_stack.push(value);
}

fn Rfetch(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const value = mini.return_stack.peek() catch |err| {
        return vm.returnStackErrorFromStackError(err);
    };
    try mini.data_stack.push(value);
}

fn eq(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(vm.fromBool(vm.Cell, a == b));
}

fn lt(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    // NOTE, the actual operator is '>' because stack order is ( b a )
    try mini.data_stack.push(vm.fromBool(vm.Cell, a > b));
}

fn lteq(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    // NOTE, the actual operator is '>=' because stack order is ( b a )
    try mini.data_stack.push(vm.fromBool(vm.Cell, a >= b));
}

fn plus(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(a +% b);
}

fn minus(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(a -% b);
}

fn multiply(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(a *% b);
}

fn divMod(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    // TODO
    // not currenly clear wether this bytecode is needed or not
    _ = mini;
}

fn uDivMod(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    const q = @divTrunc(b, a);
    const mod = @mod(b, a);
    try mini.data_stack.push(mod);
    try mini.data_stack.push(q);
}

fn negate(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const value = try mini.data_stack.pop();
    _ = value;
    // TODO
    // try mini.data_stack.push(-value);
}

fn lshift(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const value, const shift_ = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(value << @truncate(shift_));
}

fn rshift(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const value, const shift_ = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(value >> @truncate(shift_));
}

fn miniAnd(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(a & b);
}

fn miniOr(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(a | b);
}

fn xor(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(a ^ b);
}

fn invert(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const value = try mini.data_stack.pop();
    try mini.data_stack.push(~value);
}

fn selDev(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    // TODO
    _ = mini;
}

fn storeD(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    _ = mini;
    // TODO
}

fn storeAddD(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    _ = mini;
    // TODO
}

fn fetchD(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    _ = mini;
    // TODO
}

fn dup(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    try mini.data_stack.dup();
}

fn drop(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    try mini.data_stack.drop();
}

fn swap(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    try mini.data_stack.swap();
}

fn pick(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    // TODO
    _ = mini;
}

fn rot(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    try mini.data_stack.rot();
}

fn nrot(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    try mini.data_stack.nrot();
}

fn eq0(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const value = try mini.data_stack.pop();
    try mini.data_stack.push(vm.fromBool(vm.Cell, value == 0));
}

fn gt(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    // NOTE, the actual operator is '<' because stack order is ( b a )
    try mini.data_stack.push(vm.fromBool(vm.Cell, a < b));
}

fn gteq(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const a, const b = try mini.data_stack.popMultiple(2);
    // NOTE, the actual operator is '<=' because stack order is ( b a )
    try mini.data_stack.push(vm.fromBool(vm.Cell, a <= b));
}

fn storeHere(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const value = try mini.data_stack.pop();
    mini.here.store(value);
}

fn storeAddHere(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const value = try mini.data_stack.pop();
    mini.here.storeAdd(value);
}

fn fetchHere(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    try mini.data_stack.push(mini.here.fetch());
}

fn plus1(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const value = try mini.data_stack.pop();
    try mini.data_stack.push(value +% 1);
}

fn minus1(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const value = try mini.data_stack.pop();
    try mini.data_stack.push(value -% 1);
}

fn push0(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    try mini.data_stack.push(0);
}

fn pushFFFF(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    try mini.data_stack.push(0xFFFF);
}

fn push1(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    try mini.data_stack.push(1);
}

fn push2(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    try mini.data_stack.push(2);
}

fn push4(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    try mini.data_stack.push(4);
}

fn push8(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    try mini.data_stack.push(8);
}

fn cellToBytes(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    // TODO
    // instead of doing all this, could potentially just
    //   manipulate stack memory as bytes
    const value = try mini.data_stack.pop();
    const low = @as(u8, @truncate(value));
    const high = @as(u8, @truncate(value >> 8));
    try mini.data_stack.push(low);
    try mini.data_stack.push(high);
}

fn bytesToCell(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    // TODO
    // instead of doing all this, could potentially just
    //   manipulate stack memory as bytes
    const high, const low = try mini.data_stack.popMultiple(2);
    const low_byte = @as(u8, @truncate(low));
    const high_byte = @as(u8, @truncate(high));
    const value = low_byte | (@as(vm.Cell, high_byte) << 8);
    try mini.data_stack.push(value);
}

fn cmove(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    _ = mini;
    // TODO
    // mem.copyForwards()
}

fn cmoveUp(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    _ = mini;
    // TODO
    // mem.copyBackwards()
}

fn memEq(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    _ = mini;
    // TODO
    // mem.eql
}

fn maybeDup(mini: *vm.MiniVM, ctx: vm.ExecutionContext) vm.Error!void {
    const condition = try mini.data_stack.pop();
    if (vm.isTruthy(condition)) {
        try dup(mini, ctx);
    }
}

fn nip(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    try mini.data_stack.nip();
}

fn flip(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    try mini.data_stack.flip();
}

fn tuck(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    try mini.data_stack.tuck();
}

fn over(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    try mini.data_stack.over();
}
