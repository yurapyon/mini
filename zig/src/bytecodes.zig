const std_ = @import("std");

const mem = @import("memory.zig");

const stringsEqual = @import("utils/strings-equal.zig").stringsEqual;

const runtime = @import("runtime.zig");
const Runtime = runtime.Runtime;
const Cell = runtime.Cell;
const DoubleCell = runtime.DoubleCell;
const SignedCell = runtime.SignedCell;
const CompileState = runtime.CompileState;

const dictionary = @import("dictionary.zig");
const Dictionary = dictionary.Dictionary;

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

pub const bytecodes_count = bytecodes.len;

pub const cfa_codes = struct {
    pub const enter = getBytecodeToken("enter") orelse unreachable;
    pub const constant = getBytecodeToken("const") orelse unreachable;
    pub const create_does = getBytecodeToken("credo") orelse unreachable;
};

const BytecodeDefinition = struct {
    name: []const u8 = "",
    callback: BytecodeFn = panic,
    // TODO tag_only: bool,  ?
};

pub fn getBytecode(token: Cell) ?BytecodeDefinition {
    if (token < bytecodes_count) {
        return bytecodes[token];
    } else {
        return null;
    }
}

pub fn getBytecodeToken(name: []const u8) ?Cell {
    for (bytecodes, 0..) |definition, i| {
        const equal = stringsEqual(definition.name, name);
        if (equal) {
            return i;
        }
    }

    return null;
}

fn defineBuiltin(dict: *Dictionary, token: Cell) !void {
    const bytecode_definition = getBytecode(token) orelse return error.InvalidBytecode;
    const forth_vocabulary_addr = Dictionary.forth_vocabulary_addr;
    if (bytecode_definition.name.len > 0) {
        try dict.defineWord(forth_vocabulary_addr, bytecode_definition.name);
        try dict.here.comma(token);
    }
}

pub fn initBuiltins(dict: *Dictionary) !void {
    for (0..bytecodes_count) |i| {
        try defineBuiltin(dict, @intCast(i));
    }
}

const bytecodes = [_]BytecodeDefinition{
    // TODO could rename docol
    .{ .name = "enter", .callback = enter },
    .{ .name = "const", .callback = constant },
    .{ .name = "credo", .callback = createDoes },

    .{ .name = "panic", .callback = panic },
    .{ .name = "exit", .callback = exit },
    .{ .name = "execute", .callback = execute },
    .{ .name = "jump", .callback = jump },
    .{ .name = "jump0", .callback = jump0 },
    .{ .name = "quit", .callback = quit },

    .{ .name = "lit", .callback = lit },

    .{ .name = "=", .callback = eq },
    .{ .name = ">", .callback = gt },
    .{ .name = ">=", .callback = gteq },
    .{ .name = "0=", .callback = eq0 },
    .{ .name = "<", .callback = lt },
    .{ .name = "<=", .callback = lteq },

    .{ .name = "and", .callback = and_ },
    .{ .name = "or", .callback = or_ },
    .{ .name = "xor", .callback = xor },
    .{ .name = "invert", .callback = invert },
    .{ .name = "lshift", .callback = lshift },
    .{ .name = "rshift", .callback = rshift },

    .{ .name = "!", .callback = store },
    .{ .name = "+!", .callback = fetchAdd },
    .{ .name = "@", .callback = fetch },
    .{ .name = ",", .callback = comma },
    .{ .name = "c!", .callback = storeC },
    .{ .name = "+c!", .callback = fetchAddC },
    .{ .name = "c@", .callback = fetchC },
    .{ .name = "c,", .callback = commaC },

    .{ .name = ">r", .callback = toR },
    .{ .name = "r>", .callback = fromR },
    .{ .name = "r@", .callback = fetchR },

    .{ .name = "+", .callback = plus },
    .{ .name = "-", .callback = minus },
    .{ .name = "*", .callback = multiply },
    .{ .name = "/", .callback = divide },
    .{ .name = "mod", .callback = mod },
    .{ .name = "/mod", .callback = divmod },
    .{ .name = "*/", .callback = muldiv },
    .{ .name = "*/mod", .callback = muldivmod },
    .{ .name = "1+", .callback = inc },
    .{ .name = "1-", .callback = dec },

    .{ .name = "drop", .callback = drop },
    .{ .name = "dup", .callback = dup },
    .{ .name = "?dup", .callback = maybeDup },
    .{ .name = "swap", .callback = swap },
    .{ .name = "flip", .callback = flip },
    .{ .name = "over", .callback = over },
    .{ .name = "nip", .callback = nip },
    .{ .name = "tuck", .callback = tuck },
    .{ .name = "rot", .callback = rot },
    .{ .name = "-rot", .callback = nrot },

    .{ .name = "find", .callback = find },
    .{ .name = "lookup", .callback = lookup },
    .{ .name = "word", .callback = nextWord },
    .{ .name = "define", .callback = define },
    // TODO rename next-char?
    .{ .name = "next-char", .callback = nextChar },
    .{ .name = "refill", .callback = refill },
    .{ .name = "'", .callback = tick },
    .{ .name = ">number", .callback = toNumber },

    .{ .name = "move", .callback = move },
    // TODO write in forth?
    .{ .name = "mem=", .callback = memEqual },
};

pub fn enter(rt: *Runtime) Error!void {
    rt.return_stack.push(rt.program_counter);
    rt.program_counter = rt.current_token_addr + @sizeOf(Cell);
}

pub fn constant(rt: *Runtime) Error!void {
    const addr = rt.current_token_addr + @sizeOf(Cell);
    const value = mem.readCell(rt.memory, addr) catch unreachable;
    rt.data_stack.push(value);
}

pub fn createDoes(rt: *Runtime) Error!void {
    const does_addr = rt.current_token_addr + @sizeOf(Cell);
    const body_addr = does_addr + @sizeOf(Cell);
    const does = mem.readCell(rt.memory, does_addr) catch unreachable;
    rt.data_stack.push(body_addr);
    rt.return_stack.push(rt.program_counter);
    rt.setCfaToExecute(does);
}

pub fn panic(_: *Runtime) Error!void {
    return error.Panic;
}

pub fn exit(rt: *Runtime) Error!void {
    rt.program_counter = rt.return_stack.pop();
}

pub fn execute(rt: *Runtime) Error!void {
    const cfa_addr = rt.data_stack.pop();
    rt.return_stack.push(rt.program_counter);
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

    const conditional = rt.data_stack.pop();
    if (!runtime.isTruthy(conditional)) {
        try jump(rt);
    } else {
        try rt.advancePC(@sizeOf(Cell));
    }
}

pub fn quit(rt: *Runtime) Error!void {
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
    const top = rt.data_stack.peek();
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
    const addr, const value = rt.data_stack.pop2();
    try mem.writeCell(rt.memory, addr, value);
}

pub fn fetchAdd(rt: *Runtime) Error!void {
    const addr, const value = rt.data_stack.pop2();
    (try mem.cellPtr(rt.memory, addr)).* +%= value;
}

pub fn fetch(rt: *Runtime) Error!void {
    const addr = rt.data_stack.pop();
    rt.data_stack.push(try mem.readCell(rt.memory, addr));
}

pub fn comma(rt: *Runtime) Error!void {
    const value = rt.data_stack.pop();
    try rt.interpreter.dictionary.here.comma(value);
}

pub fn storeC(rt: *Runtime) Error!void {
    const addr, const value = rt.data_stack.pop2();
    const value_u8: u8 = @truncate(value);
    rt.memory[addr] = value_u8;
}

pub fn fetchAddC(rt: *Runtime) Error!void {
    const addr, const value = rt.data_stack.pop2();
    const value_u8: u8 = @truncate(value);
    rt.memory[addr] +%= value_u8;
}

pub fn fetchC(rt: *Runtime) Error!void {
    const addr = rt.data_stack.pop();
    rt.data_stack.push(rt.memory[addr]);
}

pub fn commaC(rt: *Runtime) Error!void {
    const value = rt.data_stack.pop();
    try rt.interpreter.dictionary.here.commaC(@truncate(value));
}

pub fn toR(rt: *Runtime) Error!void {
    rt.return_stack.push(rt.data_stack.pop());
}

pub fn fromR(rt: *Runtime) Error!void {
    rt.data_stack.push(rt.return_stack.pop());
}

pub fn fetchR(rt: *Runtime) Error!void {
    rt.data_stack.push(rt.return_stack.peek());
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
    const div = rt.data_stack.pop();
    const value = rt.data_stack.pop();
    const q = value / div;
    const r = value % div;
    rt.data_stack.push(@truncate(q));
    rt.data_stack.push(@truncate(r));
}

// TODO move this into DataStack definiton
pub fn muldiv(rt: *Runtime) Error!void {
    const div = rt.data_stack.pop();
    const mul = rt.data_stack.pop();
    const value = rt.data_stack.pop();
    const double_value: DoubleCell = @intCast(value);
    const double_mul: DoubleCell = @intCast(mul);
    const calc = double_value * double_mul / div;
    // NOTE
    // truncating
    // this can happen when mul is big and div is small
    rt.data_stack.push(@truncate(calc));
}

// TODO move this into DataStack definiton
pub fn muldivmod(rt: *Runtime) Error!void {
    const div = rt.data_stack.pop();
    const mul = rt.data_stack.pop();
    const value = rt.data_stack.pop();
    const double_value: DoubleCell = @intCast(value);
    const double_mul: DoubleCell = @intCast(mul);
    const q = double_value * double_mul / div;
    const r = double_value * double_mul % div;
    // NOTE
    // truncating
    // this can happen when mul is big and div is small
    rt.data_stack.push(@truncate(q));
    rt.data_stack.push(@truncate(r));
}

pub fn find(rt: *Runtime) Error!void {
    const len, const addr = rt.data_stack.pop2();
    const word = try mem.constSliceFromAddrAndLen(rt.memory, addr, len);

    const context_vocabulary_addr = rt.interpreter.dictionary.context.fetch();

    if (try rt.interpreter.dictionary.findWord(
        context_vocabulary_addr,
        word,
        false,
    )) |word_info| {
        rt.data_stack.push(word_info.definition_addr);
        rt.data_stack.push(runtime.cellFromBoolean(true));
    } else {
        rt.data_stack.push(0);
        rt.data_stack.push(runtime.cellFromBoolean(false));
    }
}

pub fn lookup(rt: *Runtime) Error!void {
    const len, const addr = rt.data_stack.pop2();
    const word = try mem.constSliceFromAddrAndLen(rt.memory, addr, len);

    const maybe_lookup_result = rt.interpreter.lookupString(word) catch |err| switch (err) {
        error.InvalidBase, error.Overflow => null,
        else => |e| return e,
    };

    if (maybe_lookup_result) |lookup_result| {
        switch (lookup_result) {
            .word => |word_info| {
                const is_compile_word = word_info.context_addr == Dictionary.compiler_vocabulary_addr;
                rt.data_stack.push(word_info.definition_addr);
                rt.data_stack.push(runtime.cellFromBoolean(is_compile_word));
                rt.data_stack.push(runtime.cellFromBoolean(true));
                return;
            },
            else => {},
        }
    }

    rt.data_stack.push(0);
    rt.data_stack.push(0);
    rt.data_stack.push(runtime.cellFromBoolean(false));
}

pub fn nextWord(rt: *Runtime) Error!void {
    // NOTE
    // This doesnt try to refill,
    //   because refilling invalidates what was stored in the input buffer
    const range = rt.input_buffer.readNextWordRange() orelse {
        rt.data_stack.push(0);
        rt.data_stack.push(0);
        return;
    };
    rt.data_stack.push(range.address);
    rt.data_stack.push(range.len);
}

pub fn define(rt: *Runtime) Error!void {
    const len, const addr = rt.data_stack.pop2();
    const word = try mem.constSliceFromAddrAndLen(rt.memory, addr, len);
    const vocabulary_addr = rt.interpreter.dictionary.current.fetch();
    try rt.interpreter.dictionary.defineWord(vocabulary_addr, word);
}

pub fn nextChar(rt: *Runtime) Error!void {
    // NOTE
    // This doesnt try to refill,
    //   because refilling invalidates what was stored in the input buffer
    const char = rt.input_buffer.readNextChar() orelse {
        return error.UnexpectedEndOfInput;
    };
    rt.data_stack.push(char);
}

pub fn refill(rt: *Runtime) Error!void {
    const did_refill = try rt.input_buffer.refill();
    rt.data_stack.push(runtime.cellFromBoolean(did_refill));
}

pub fn tick(rt: *Runtime) Error!void {
    // NOTE
    // This doesnt try to refill,
    //   because refilling invalidates what was stored in the input buffer

    const state = try CompileState.fromCell(rt.interpreter.state.fetch());

    const word = rt.input_buffer.readNextWord() orelse {
        return error.UnexpectedEndOfInput;
    };
    const vocabulary_addr = rt.interpreter.dictionary.context.fetch();
    if (try rt.interpreter.dictionary.findWord(
        vocabulary_addr,
        word,
        state == .compile,
    )) |word_info| {
        const cfa_addr = try rt.interpreter.dictionary.toCfa(word_info.definition_addr);
        rt.data_stack.push(cfa_addr);
    } else {
        rt.last_evaluated_word = word;
        return error.WordNotFound;
    }
}

pub fn lit(rt: *Runtime) Error!void {
    try rt.assertValidProgramCounter();
    const value = try mem.readCell(rt.memory, rt.program_counter);
    rt.data_stack.push(value);
    try rt.advancePC(@sizeOf(Cell));
}

pub fn toNumber(rt: *Runtime) Error!void {
    const len, const addr = rt.data_stack.pop2();
    const word = try mem.constSliceFromAddrAndLen(rt.memory, addr, len);
    const base_addr = runtime.MainMemoryLayout.offsetOf("base");
    const base = mem.readCell(rt.memory, base_addr) catch unreachable;
    const number_usize = rt.interpreter.parseNumberCallback(word, base) catch {
        rt.data_stack.push(0);
        rt.data_stack.push(0);
        return;
    };

    const cell = @as(Cell, @truncate(number_usize & 0xffff));
    rt.data_stack.push(cell);
    rt.data_stack.push(0xffff);
}

pub fn move(rt: *Runtime) Error!void {
    const std = @import("std");

    const count = rt.data_stack.pop();
    const destination, const source = rt.data_stack.pop2();
    const source_slice = try mem.constSliceFromAddrAndLen(
        rt.memory,
        source,
        count,
    );
    const destination_slice = try mem.sliceFromAddrAndLen(
        rt.memory,
        destination,
        count,
    );

    if (destination > source) {
        std.mem.copyBackwards(u8, destination_slice, source_slice);
    } else {
        std.mem.copyForwards(u8, destination_slice, source_slice);
    }
}

pub fn memEqual(rt: *Runtime) Error!void {
    const std = @import("std");

    const count = rt.data_stack.pop();
    const b_addr, const a_addr = rt.data_stack.pop2();
    const a_slice = try mem.constSliceFromAddrAndLen(rt.memory, a_addr, count);
    const b_slice = try mem.constSliceFromAddrAndLen(rt.memory, b_addr, count);
    const areEqual = std.mem.eql(u8, a_slice, b_slice);
    rt.data_stack.push(runtime.cellFromBoolean(areEqual));
}
