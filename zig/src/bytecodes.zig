const std = @import("std");
const mem = std.mem;

const vm = @import("mini.zig");

// ===

fn nop(_: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {}

fn compileSelf(mini: *vm.MiniVM, ctx: vm.ExecutionContext) vm.Error!void {
    mini.dictionary.here.commaC(ctx.current_bytecode);
}

fn cannotInterpret(_: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    return error.CannotInterpret;
}

fn cannotCompile(_: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    return error.CannotCompile;
}

const BytecodeDefinition = struct {
    name: []const u8 = "",
    compileSemantics: vm.BytecodeFn = nop,
    interpretSemantics: vm.BytecodeFn = nop,
    executeSemantics: vm.BytecodeFn = nop,
    is_immediate: bool = false,
};

pub fn getBytecodeDefinition(bytecode: u8) BytecodeDefinition {
    return switch (bytecode) {
        // TODO probably shouldnt hardcode these values
        inline 0b00000000...0b01101111 => |byte| {
            const id = byte & 0x7f;
            return lookup_table[id];
        },
        inline 0b01110000...0b01111111 => data_definition,
        inline 0b10000000...0b11111111 => abs_jump_definition,
    };
}

pub fn lookupBytecodeByName(name: []const u8) ?u8 {
    if (mem.eql(u8, name, data_definition.name)) {
        return base_data_bytecode;
    }
    if (mem.eql(u8, name, abs_jump_definition.name)) {
        return base_abs_jump_bytecode;
    }
    for (lookup_table, 0..) |named_callback, i| {
        const eql = mem.eql(u8, named_callback.name, name);
        if (eql) {
            return @truncate(i);
        }
    }

    return null;
}

test "bytecode-utils" {
    // TODO
}

// ===

fn constructBasicBytecode(
    name: []const u8,
    callback: vm.BytecodeFn,
) BytecodeDefinition {
    return .{
        .name = name,
        .compileSemantics = compileSelf,
        .interpretSemantics = callback,
        .executeSemantics = callback,
        .is_immediate = false,
    };
}

fn constructBasicImmediateBytecode(
    name: []const u8,
    callback: vm.BytecodeFn,
) BytecodeDefinition {
    return .{
        .name = name,
        .compileSemantics = callback,
        .interpretSemantics = callback,
        .executeSemantics = callback,
        .is_immediate = true,
    };
}

fn constructExecuteOnlyBytecode(
    name: []const u8,
    callback: vm.BytecodeFn,
) BytecodeDefinition {
    return .{
        .name = name,
        .compileSemantics = cannotCompile,
        .interpretSemantics = cannotInterpret,
        .executeSemantics = callback,
        .is_immediate = false,
    };
}

const lookup_table = [_]BytecodeDefinition{
    // ===
    constructBasicBytecode("bye", bye),
    constructBasicBytecode("quit", quit),
    constructBasicBytecode("exit", exit),
    constructBasicBytecode("panic", panic),

    constructBasicBytecode("'", tick),
    constructBasicImmediateBytecode("[']", bracketTick),
    constructBasicImmediateBytecode("]", rBracket),
    constructBasicBytecode("[", lBracket),

    constructBasicBytecode("find", find),
    constructBasicBytecode("word", nextWord),
    constructBasicBytecode("next-char", nextChar),
    constructBasicBytecode("define", define),

    constructExecuteOnlyBytecode("branch", branch),
    constructExecuteOnlyBytecode("branch0", branch0),
    constructBasicBytecode("execute", execute),
    constructExecuteOnlyBytecode("tailcall", tailcall),

    // ===
    constructBasicBytecode("!", store),
    constructBasicBytecode("+!", storeAdd),
    constructBasicBytecode("@", fetch),
    constructBasicBytecode(",", comma),
    constructExecuteOnlyBytecode("lit", lit),

    constructBasicBytecode("c!", storeC),
    constructBasicBytecode("+c!", storeAddC),
    constructBasicBytecode("c@", fetchC),
    constructBasicBytecode("c,", commaC),
    constructExecuteOnlyBytecode("litc", litC),

    constructBasicBytecode(">r", toR),
    constructBasicBytecode("r>", fromR),
    constructBasicBytecode("r@", Rfetch),

    constructBasicBytecode("=", eq),
    constructBasicBytecode("<", lt),
    constructBasicBytecode("<=", lteq),

    // ===
    constructBasicBytecode("+", plus),
    constructBasicBytecode("-", minus),
    constructBasicBytecode("*", multiply),
    constructBasicBytecode("/mod", divMod),
    constructBasicBytecode("u/mod", uDivMod),
    constructBasicBytecode("negate", negate),

    constructBasicBytecode("lshift", lshift),
    constructBasicBytecode("rshift", rshift),
    constructBasicBytecode("and", miniAnd),
    constructBasicBytecode("or", miniOr),
    constructBasicBytecode("xor", xor),
    constructBasicBytecode("invert", invert),

    constructBasicBytecode("seldev", selDev),
    constructBasicBytecode("d!", storeD),
    constructBasicBytecode("d+!", storeAddD),
    constructBasicBytecode("d@", fetchD),

    // ===
    constructBasicBytecode("dup", dup),
    constructBasicBytecode("drop", drop),
    constructBasicBytecode("swap", swap),
    constructBasicBytecode("pick", pick),

    constructBasicBytecode("rot", rot),
    constructBasicBytecode("-rot", nrot),
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
    constructBasicBytecode("0=", eq0),
    constructBasicBytecode(">", gt),
    constructBasicBytecode(">=", gteq),

    constructBasicBytecode("here!", storeHere),
    constructBasicBytecode("here+!", storeAddHere),
    constructBasicBytecode("here@", fetchHere),

    constructBasicBytecode("1+", plus1),
    constructBasicBytecode("1-", minus1),

    constructBasicBytecode("0", push0),
    constructBasicBytecode("0xffff", pushFFFF),

    constructBasicBytecode("1", push1),
    constructBasicBytecode("2", push2),
    constructBasicBytecode("4", push4),
    constructBasicBytecode("8", push8),

    constructBasicBytecode("cell>bytes", cellToBytes),
    constructBasicBytecode("bytes>cell", bytesToCell),

    // ===
    constructBasicBytecode("cmove", cmove),
    constructBasicBytecode("cmove>", cmoveUp),
    constructBasicBytecode("mem=", memEq),

    constructBasicBytecode("?dup", maybeDup),

    constructBasicBytecode("nip", nip),
    constructBasicBytecode("flip", flip),
    constructBasicBytecode("tuck", tuck),
    constructBasicBytecode("over", over),

    .{},
    .{},
    .{},
    .{},

    .{},
    .{},
    .{},
    .{},

    // ===
    constructBasicBytecode("##.s", printStack),
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

fn panic(_: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    return error.Panic;
}

/// Pushes whether word is bytecode or not
///   followed by bytecode or cfa_addr
fn tick(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const result = try mini.readWordAndGetAddress();
    try mini.data_stack.push(vm.fromBool(vm.Cell, result.is_bytecode));
    try mini.data_stack.push(result.value);
}

fn bracketTick(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const result = try mini.readWordAndGetAddress();
    if (result.is_bytecode) {
        mini.dictionary.compileLitC(@truncate(result.value));
    } else {
        mini.dictionary.compileLit(result.value);
    }
}

fn rBracket(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    mini.state.store(@intFromEnum(vm.CompileState.interpret));
}

fn lBracket(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    mini.state.store(@intFromEnum(vm.CompileState.compile));
}

fn branch(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
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
    const word = try mini.popSlice();
    if (try mini.dictionary.lookup(word)) |definition_addr| {
        try mini.data_stack.push(definition_addr);
        try mini.data_stack.push(vm.fromBool(vm.Cell, true));
    } else {
        try mini.data_stack.push(0);
        try mini.data_stack.push(vm.fromBool(vm.Cell, false));
    }
}

fn nextWord(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    // TODO
    // this currently wont work because the input source buffer memory
    //   isn't a part of the main vm memory
    _ = mini;
}

fn nextChar(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    // TODO this is messy
    if (try mini.input_source.readNextChar()) |char| {
        try mini.data_stack.push(char);
    } else {
        try mini.input_source.refill();
        if (try mini.input_source.readNextChar()) |char| {
            try mini.data_stack.push(char);
        } else {
            return error.Panic;
        }
    }
}

fn define(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const word = try mini.popSlice();
    try mini.dictionary.defineWord(word);
}

fn execute(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const addr = try mini.data_stack.pop();
    try mini.absoluteJump(addr, true);
}

/// This jumps to the following address in memory without
///   pushing anything to the return stack
fn tailcall(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const addr = mini.readCellAndAdvancePC();
    // TODO this mask should be a constant somewhere
    const masked_addr = addr & 0x7fff;
    try mini.absoluteJump(masked_addr, false);
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
    mini.dictionary.here.comma(value);
}

fn lit(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
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
    mini.dictionary.here.commaC(@truncate(value));
}

fn litC(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
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
    // TODO need to figure out signed int handling
    const value = try mini.data_stack.pop();
    _ = value;
    // try mini.data_stack.push(-value);
}

fn lshift(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const shift_, const value = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(value << @truncate(shift_));
}

fn rshift(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const shift_, const value = try mini.data_stack.popMultiple(2);
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
    const idx = try mini.data_stack.pop();
    const value = (try mini.data_stack.index(idx)).*;
    try mini.data_stack.push(value);
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
    mini.dictionary.here.store(value);
}

fn storeAddHere(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const value = try mini.data_stack.pop();
    mini.dictionary.here.storeAdd(value);
}

fn fetchHere(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    try mini.data_stack.push(mini.dictionary.here.fetch());
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

fn printStack(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    std.debug.print("stack ==\n", .{});
    for (mini.data_stack.asSlice(), 0..) |cell, i| {
        std.debug.print("{}: {}\n", .{ i, cell });
    }
}

// ===

pub const base_data_bytecode = 0b01110000;

const data_definition = BytecodeDefinition{
    .name = "##data",
    .compileSemantics = dataCompile,
    .interpretSemantics = dataCompile,
    .executeSemantics = dataExecute,
    .is_immediate = true,
};

fn dataCompile(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const data = try mini.popSlice();
    mini.dictionary.compileData(data);
}

fn dataExecute(mini: *vm.MiniVM, ctx: vm.ExecutionContext) vm.Error!void {
    // TODO verify this works
    const high = ctx.current_bytecode & 0x0f;
    const low = mini.readByteAndAdvancePC();
    const addr = mini.program_counter.fetch();
    const length = @as(vm.Cell, high) << 8 | low;
    try mini.data_stack.push(addr);
    try mini.data_stack.push(length);
    mini.program_counter.storeAdd(length);
}

pub const base_abs_jump_bytecode = 0b10000000;

const abs_jump_definition = BytecodeDefinition{
    .name = "##absjump",
    .compileSemantics = absjumpCompile,
    .interpretSemantics = absjumpCompile,
    .executeSemantics = absjumpExecute,
    .is_immediate = true,
};

fn absjumpCompile(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const cfa_addr = try mini.data_stack.pop();
    mini.dictionary.compileAbsJump(cfa_addr);
}

fn absjumpExecute(mini: *vm.MiniVM, ctx: vm.ExecutionContext) vm.Error!void {
    // TODO verify this works
    const high = ctx.current_bytecode & 0x7f;
    const low = mini.readByteAndAdvancePC();
    const addr = @as(vm.Cell, high) << 8 | low;
    try mini.absoluteJump(addr, true);
}

test "bytecodes" {
    const testing = @import("std").testing;

    const memory = try vm.allocateMemory(testing.allocator);
    defer testing.allocator.free(memory);

    var mini: vm.MiniVM = undefined;
    try mini.init(memory);

    try mini.data_stack.push(1);
    try mini.data_stack.push(0xabcd);

    try testWords(
        &mini,
        &[_]VmWordTest{
            .{
                .word = "dup",
                .stack = &[_]u16{ 1, 0xabcd, 0xabcd },
            },
            .{
                .word = "0xffff",
                .stack = &[_]u16{ 1, 0xabcd, 0xabcd, 0xffff },
            },
            .{
                .word = "4",
                .stack = &[_]u16{ 1, 0xabcd, 0xabcd, 0xffff, 4 },
            },
            .{
                .word = "rshift",
                .stack = &[_]u16{ 1, 0xabcd, 0xabcd, 0x0fff },
            },
            .{
                .word = "and",
                .stack = &[_]u16{ 1, 0xabcd, 0x0bcd },
            },
        },
    );

    mini.data_stack.clear();

    try testWords(
        &mini,
        &[_]VmWordTest{
            .{
                .word = "1",
                .stack = &[_]u16{1},
            },
            .{
                .word = "2",
                .stack = &[_]u16{ 1, 2 },
            },
            .{
                .word = "+",
                .stack = &[_]u16{3},
            },
            .{
                .word = "4",
                .stack = &[_]u16{ 3, 4 },
            },
            .{
                .word = "tuck",
                .stack = &[_]u16{ 4, 3, 4 },
            },
        },
    );
}

const TestMode = enum {
    compile,
    interpret,
    execute,
};

const VmWordTest = struct {
    word: []const u8,
    stack: []const vm.Cell,
    mode: TestMode = .interpret,
};

fn testWords(mini: *vm.MiniVM, word_tests: []const VmWordTest) !void {
    // TODO is there a way to print which line failed?
    for (word_tests) |word_test| {
        try testBytecodeStack(
            mini,
            word_test.word,
            word_test.mode,
            word_test.stack,
        );
    }
}

fn testBytecodeStack(
    mini: *vm.MiniVM,
    word: []const u8,
    mode: TestMode,
    expect_stack: []const vm.Cell,
) !void {
    const stack = @import("stack.zig");

    const bytecode = lookupBytecodeByName(word) orelse unreachable;
    const bytecode_definition = getBytecodeDefinition(bytecode);

    const ctx = vm.ExecutionContext{
        .current_bytecode = bytecode,
    };

    try switch (mode) {
        .compile => bytecode_definition.compileSemantics(mini, ctx),
        .interpret => bytecode_definition.interpretSemantics(mini, ctx),
        .execute => bytecode_definition.executeSemantics(mini, ctx),
    };

    try stack.expectStack(mini.data_stack, expect_stack);
}