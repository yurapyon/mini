const std = @import("std");

const vm = @import("mini.zig");
const utils = @import("utils.zig");

//

// TODO
// possible new bytecodes
//   bytes, ?
//   bytes! ?
//   / mod u/ umod ?
//     could define these as bytecodes then /mod and u/mod be forth words

// ===

pub const base_abs_jump_bytecode = 0b10000000;

const abs_jump_definition = BytecodeDefinition{
    .compileSemantics = cannotCompile,
    .interpretSemantics = cannotInterpret,
    .executeSemantics = executeAbsJump,
};

fn executeAbsJump(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    // const high = ctx.current_bytecode & 0x7f;
    // const low = try mini.readByteAndAdvancePC();
    // const addr = @as(vm.Cell, high) << 8 | low;
    const addr = try mini.readCellAndAdvancePC();
    try mini.absoluteJump(addr, true);
}

// ===

fn nop(_: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {}

fn compileSelf(mini: *vm.MiniVM, ctx: vm.ExecutionContext) vm.Error!void {
    try mini.dictionary.here.commaC(mini.dictionary.memory, ctx.current_bytecode);
}

fn cannotCompile(_: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    return error.CannotCompile;
}

fn cannotInterpret(_: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    return error.CannotInterpret;
}

const BytecodeDefinition = struct {
    name: []const u8 = "",
    compileSemantics: vm.BytecodeFn = nop,
    interpretSemantics: vm.BytecodeFn = nop,
    executeSemantics: vm.BytecodeFn = nop,
};

pub fn getBytecodeDefinition(bytecode: u8) BytecodeDefinition {
    return switch (bytecode) {
        inline 0...(base_abs_jump_bytecode - 1) => |byte| {
            return lookup_table[byte];
        },
        else => abs_jump_definition,
    };
}

pub fn lookupBytecodeByName(name: []const u8) ?u8 {
    for (lookup_table, 0..) |named_callback, i| {
        const eql = utils.stringsEqual(named_callback.name, name);
        if (eql) {
            return @truncate(i);
        }
    }

    return null;
}

test "bytecode-utils" {
    const testing = std.testing;

    try testing.expectEqual(0, lookupBytecodeByName("panic"));
    try testing.expectEqual(null, lookupBytecodeByName("_definetly-not-defined_"));
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
    };
}

fn constructTagBytecode(
    name: []const u8,
    executeCallback: vm.BytecodeFn,
) BytecodeDefinition {
    return .{
        .name = name,
        .compileSemantics = cannotCompile,
        .interpretSemantics = cannotInterpret,
        .executeSemantics = executeCallback,
    };
}

const lookup_table = [128]BytecodeDefinition{
    // NOTE
    // panic is bytecode '0' so that you can just zero the memory to inialize it
    constructBasicBytecode("panic", panic),
    constructBasicBytecode("bye", bye),
    constructBasicBytecode("quit", quit),
    constructTagBytecode("exit", exit),

    constructBasicBytecode("'", tick),
    constructBasicImmediateBytecode("[']", bracketTick),
    constructBasicBytecode("]", rBracket),
    constructBasicImmediateBytecode("[", lBracket),

    constructBasicBytecode("find", find),
    constructBasicBytecode("word", nextWord),
    constructBasicBytecode(">terminator", toTerminator),
    constructBasicBytecode("define", define),

    constructTagBytecode("branch", branch),
    constructTagBytecode("branch0", branch0),
    constructBasicBytecode("execute", execute),
    constructTagBytecode("tailcall", tailcall),

    // ===

    constructBasicBytecode("!", store),
    constructBasicBytecode("+!", storeAdd),
    constructBasicBytecode("@", fetch),
    constructBasicBytecode(",", comma),
    constructTagBytecode("lit", lit),

    constructBasicBytecode("c!", storeC),
    constructBasicBytecode("+c!", storeAddC),
    constructBasicBytecode("c@", fetchC),
    constructBasicBytecode("c,", commaC),
    constructTagBytecode("litc", litC),

    constructBasicBytecode(">r", toR),
    constructBasicBytecode("r>", fromR),
    constructBasicBytecode("r@", Rfetch),

    constructBasicBytecode("d!", storeD),
    constructBasicBytecode("d+!", storeAddD),
    constructBasicBytecode("d@", fetchD),

    constructBasicBytecode("=", eq),
    constructBasicBytecode("<", lt),
    constructBasicBytecode("<=", lteq),
    constructBasicBytecode("0=", eq0),
    constructBasicBytecode(">", gt),
    constructBasicBytecode(">=", gteq),

    constructBasicBytecode("+", plus),
    constructBasicBytecode("-", minus),
    constructBasicBytecode("*", multiply),
    constructBasicBytecode("/mod", divMod),
    constructBasicBytecode("u/mod", uDivMod),
    constructBasicBytecode("negate", negate),

    constructBasicBytecode("1+", plus1),
    constructBasicBytecode("1-", minus1),

    constructBasicBytecode("lshift", lshift),
    constructBasicBytecode("rshift", rshift),
    constructBasicBytecode("and", miniAnd),
    constructBasicBytecode("or", miniOr),
    constructBasicBytecode("xor", xor),
    constructBasicBytecode("invert", invert),

    constructBasicBytecode("dup", dup),
    constructBasicBytecode("drop", drop),
    constructBasicBytecode("swap", swap),
    constructBasicBytecode("pick", pick),
    constructBasicBytecode("nip", nip),
    constructBasicBytecode("flip", flip),
    constructBasicBytecode("tuck", tuck),
    constructBasicBytecode("over", over),
    constructBasicBytecode("rot", rot),
    constructBasicBytecode("-rot", nrot),
    constructBasicBytecode("?dup", maybeDup),

    constructBasicBytecode("next-char", nextChar),
    constructTagBytecode("ext", ext),

    constructBasicBytecode("cell>bytes", cellToBytes),
    constructBasicBytecode("bytes>cell", bytesToCell),

    constructBasicBytecode("cmove", cmove),
    constructBasicBytecode("cmove>", cmoveUp),
    constructBasicBytecode("mem=", memEq),

    constructTagBytecode("call", executeAbsJump),

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
    const should_continue = try mini.callbacks.onExit(mini, mini.callbacks.userdata);
    if (should_continue) {
        const addr = try mini.return_stack.pop();
        try mini.absoluteJump(addr, false);
    }
}

fn panic(_: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    return error.Panic;
}

fn tick(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const word = mini.input_source.readNextWord() orelse return error.UnexpectedEndOfInput;
    const result = try mini.lookupStringAndGetAddress(word);
    if (result.is_bytecode) {
        try mini.data_stack.push(result.value);
    } else {
        const cfa_addr = try mini.dictionary.toCfa(result.value);
        try mini.data_stack.push(cfa_addr);
    }
}

fn bracketTick(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const word = mini.input_source.readNextWord() orelse return error.UnexpectedEndOfInput;
    const result = try mini.lookupStringAndGetAddress(word);
    if (result.is_bytecode) {
        try mini.dictionary.compileLitC(@truncate(result.value));
    } else {
        const cfa_addr = try mini.dictionary.toCfa(result.value);
        try mini.dictionary.compileLit(cfa_addr);
    }
}

fn rBracket(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    mini.state.store(@intFromEnum(vm.CompileState.compile));
}

fn lBracket(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    mini.state.store(@intFromEnum(vm.CompileState.interpret));
}

fn branch(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const pc = mini.program_counter.fetch();
    const byte_jump = try mini.readByteAndAdvancePC();
    const signed_byte_jump = @as(i8, @bitCast(byte_jump));
    // NOTE
    // this intCast is from i8 to SignedCell
    // this is to preserve negativity
    const signed_cell_jump = @as(vm.SignedCell, @intCast(signed_byte_jump));
    const cell_jump = @as(vm.Cell, @bitCast(signed_cell_jump));
    try mini.absoluteJump(pc +% cell_jump, false);
}

fn branch0(mini: *vm.MiniVM, ctx: vm.ExecutionContext) vm.Error!void {
    const condition = try mini.data_stack.pop();
    if (!vm.isTruthy(condition)) {
        return try branch(mini, ctx);
    } else {
        _ = try mini.readByteAndAdvancePC();
    }
}

fn find(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const word = try mini.popSlice();
    const result_or_error = mini.lookupStringAndGetAddress(word);
    const result = result_or_error catch |err| switch (err) {
        error.WordNotFound => {
            try mini.data_stack.push(0);
            try mini.data_stack.push(0);
            try mini.data_stack.push(vm.fromBool(vm.Cell, false));
            return;
        },
        else => return err,
    };
    try mini.data_stack.push(result.value);
    try mini.data_stack.push(vm.fromBool(vm.Cell, !result.is_bytecode));
    try mini.data_stack.push(vm.fromBool(vm.Cell, true));
}

fn nextWord(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    // TODO should try and refill
    const range = mini.input_source.readNextWordRange() orelse return error.UnexpectedEndOfInput;
    try mini.data_stack.push(range.address);
    try mini.data_stack.push(range.len);
}

fn nextChar(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    // TODO this is messy
    if (mini.input_source.readNextChar()) |char| {
        try mini.data_stack.push(char);
    } else {
        _ = try mini.input_source.refill();
        if (mini.input_source.readNextChar()) |char| {
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

// NOTE
// this only works for forth words
// TODO
// should a version of this be made that works for bytecodes?
fn execute(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const addr = try mini.data_stack.pop();
    try mini.absoluteJump(addr, true);
}

// TODO this should read jumps the same way absjump does
/// This jumps to the following address in memory without
///   pushing anything to the return stack
fn tailcall(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const addr = try mini.readCellAndAdvancePC();
    // const swapped_addr = @byteSwap(addr);
    // TODO this mask should be a constant somewhere
    // const masked_addr = swapped_addr & 0x7fff;
    try mini.absoluteJump(addr, false);
}

fn store(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const addr, const value = try mini.data_stack.popMultiple(2);
    const mem_ptr = try vm.mem.cellAt(mini.memory, addr);
    mem_ptr.* = value;
}

fn storeAdd(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const addr, const value = try mini.data_stack.popMultiple(2);
    const mem_ptr = try vm.mem.cellAt(mini.memory, addr);
    mem_ptr.* +%= value;
}

fn fetch(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const addr = try mini.data_stack.pop();
    const mem_ptr = try vm.mem.cellAt(mini.memory, addr);
    try mini.data_stack.push(mem_ptr.*);
}

fn comma(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const value = try mini.data_stack.pop();
    try mini.dictionary.here.comma(mini.dictionary.memory, value);
}

fn lit(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const value = try mini.readCellAndAdvancePC();
    try mini.data_stack.push(value);
}

fn storeC(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const addr, const value = try mini.data_stack.popMultiple(2);
    const byte: u8 = @truncate(value);
    const ptr = try vm.mem.checkedAccess(mini.memory, addr);
    ptr.* = byte;
}

fn storeAddC(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const addr, const value = try mini.data_stack.popMultiple(2);
    const byte: u8 = @truncate(value);
    const ptr = try vm.mem.checkedAccess(mini.memory, addr);
    ptr.* += byte;
}

fn fetchC(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const addr = try mini.data_stack.pop();
    const value = try vm.mem.checkedRead(mini.memory, addr);
    try mini.data_stack.push(value);
}

fn commaC(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const value = try mini.data_stack.pop();
    try mini.dictionary.here.commaC(mini.dictionary.memory, @truncate(value));
}

fn litC(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const byte = try mini.readByteAndAdvancePC();
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
    const b, const a = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(vm.fromBool(vm.Cell, a < b));
}

fn lteq(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const b, const a = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(vm.fromBool(vm.Cell, a <= b));
}

fn plus(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const b, const a = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(a +% b);
}

fn minus(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const b, const a = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(a -% b);
}

fn multiply(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const b, const a = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(a *% b);
}

fn divMod(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const b, const a = try mini.data_stack.popMultiple(2);
    const signed_a = @as(vm.SignedCell, @bitCast(a));
    const signed_b = @as(vm.SignedCell, @bitCast(b));
    const quotient = try std.math.divTrunc(vm.SignedCell, signed_a, signed_b);
    const remainder = try std.math.mod(vm.SignedCell, signed_a, signed_b);
    try mini.data_stack.push(@bitCast(remainder));
    try mini.data_stack.push(@bitCast(quotient));
}

fn uDivMod(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const b, const a = try mini.data_stack.popMultiple(2);
    const quotient = try std.math.divTrunc(vm.Cell, a, b);
    const remainder = try std.math.mod(vm.Cell, a, b);
    try mini.data_stack.push(remainder);
    try mini.data_stack.push(quotient);
}

fn negate(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const value = try mini.data_stack.pop();
    const signed_value = @as(vm.SignedCell, @bitCast(value));
    try mini.data_stack.push(@bitCast(-signed_value));
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
    const b, const a = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(a & b);
}

fn miniOr(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const b, const a = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(a | b);
}

fn xor(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const b, const a = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(a ^ b);
}

fn invert(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const value = try mini.data_stack.pop();
    try mini.data_stack.push(~value);
}

fn storeD(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    try mini.devices.store(0xbeef);
}

fn storeAddD(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    try mini.devices.storeAdd(0xbeef);
}

fn fetchD(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    _ = try mini.devices.fetch(0xbeef);
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

fn ext(mini: *vm.MiniVM, ctx: vm.ExecutionContext) vm.Error!void {
    const shortcode = try mini.readCellAndAdvancePC();
    const exts = @import("ext_bytecodes.zig");
    try exts.executeExt(shortcode, mini, ctx);
}

fn toTerminator(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const definition_addr = try mini.data_stack.pop();
    const terminator_addr = try mini.dictionary.toTerminator(definition_addr);
    try mini.data_stack.push(terminator_addr);
}

fn eq0(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const value = try mini.data_stack.pop();
    try mini.data_stack.push(vm.fromBool(vm.Cell, value == 0));
}

fn gt(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const b, const a = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(vm.fromBool(vm.Cell, a > b));
}

fn gteq(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const b, const a = try mini.data_stack.popMultiple(2);
    try mini.data_stack.push(vm.fromBool(vm.Cell, a >= b));
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

// TODO could rename these next two to split and join
fn cellToBytes(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const value = try mini.data_stack.pop();
    const high = @as(u8, @truncate(value >> 8));
    const low = @as(u8, @truncate(value));
    try mini.data_stack.push(high);
    try mini.data_stack.push(low);
}

fn bytesToCell(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const low, const high = try mini.data_stack.popMultiple(2);
    const low_byte = @as(u8, @truncate(low));
    const high_byte = @as(u8, @truncate(high));
    const value = low_byte | (@as(vm.Cell, high_byte) << 8);
    try mini.data_stack.push(value);
}

fn cmove(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    _ = mini;
    // TODO
    // std.mem.copyForwards()
}

fn cmoveUp(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    _ = mini;
    // TODO
    // std.mem.copyBackwards()
}

fn memEq(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    _ = mini;
    // TODO
    // std.mem.eql
}

fn maybeDup(mini: *vm.MiniVM, ctx: vm.ExecutionContext) vm.Error!void {
    const condition = try mini.data_stack.peek();
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

// ===

test "bytecodes" {
    const testing = @import("std").testing;

    const memory = try vm.mem.allocateCellAlignedMemory(
        testing.allocator,
        vm.max_memory_size,
    );
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
                .word = "-",
                .stack = &[_]u16{@bitCast(@as(vm.SignedCell, -1))},
            },
            .{
                .word = "negate",
                .stack = &[_]u16{@bitCast(@as(vm.SignedCell, 1))},
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
