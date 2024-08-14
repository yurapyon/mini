const mem = @import("memory.zig");
const utils = @import("utils.zig");

const runtime = @import("runtime.zig");
const Runtime = runtime.Runtime;
const Cell = runtime.Cell;
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
};

pub const BytecodeFn = *const fn (runtime: *Runtime) Error!void;

pub const bytecodes_count = 64;

pub const enter_code = getBytecodeToken("enter") orelse unreachable;

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
        const equal = utils.stringsEqual(definition.name, name);
        if (equal) {
            return i;
        }
    }

    return null;
}

fn defineBuiltin(dict: *Dictionary, token: Cell) !void {
    const bytecode_definition = getBytecode(token) orelse return error.InvalidBytecode;
    const wordlist_idx = CompileState.interpret.toWordlistIndex() catch unreachable;
    if (bytecode_definition.name.len > 0) {
        try dict.define(wordlist_idx, bytecode_definition.name);
        try dict.here.comma(token);
    }
}

pub fn initBuiltins(dict: *Dictionary) !void {
    for (0..bytecodes_count) |i| {
        try defineBuiltin(dict, @intCast(i));
    }
}

const bytecodes = [bytecodes_count]BytecodeDefinition{
    .{ .name = "nop", .callback = nop },
    .{ .name = "exit", .callback = exit },
    .{ .name = "enter", .callback = enter },
    .{ .name = "execute", .callback = execute },
    .{ .name = "jump", .callback = jump },
    .{ .name = "jump0", .callback = jump0 },
    .{ .name = "quit", .callback = quit },
    .{ .name = "bye", .callback = bye },

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
    .{ .name = "1+", .callback = inc },
    .{ .name = "1-", .callback = dec },

    .{ .name = "drop", .callback = drop },
    .{ .name = "dup", .callback = dup },
    .{ .name = "swap", .callback = swap },
    .{ .name = "flip", .callback = flip },
    .{ .name = "over", .callback = over },
    .{ .name = "nip", .callback = nip },
    .{ .name = "tuck", .callback = tuck },
    .{ .name = "rot", .callback = rot },
    .{ .name = "-rot", .callback = nrot },

    .{ .name = "find", .callback = find },
    .{ .name = "word", .callback = nextWord },
    .{ .name = "define", .callback = define },
    .{ .name = "next-char", .callback = nextChar },
    .{ .name = "refill", .callback = refill },
    .{ .name = "'", .callback = tick },

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

fn nop(_: *Runtime) Error!void {}

fn panic(_: *Runtime) Error!void {
    return error.Panic;
}

fn enter(rt: *Runtime) Error!void {
    rt.return_stack.push(rt.program_counter);
    rt.program_counter = rt.current_token_addr + @sizeOf(Cell);
}

fn exit(rt: *Runtime) Error!void {
    rt.program_counter = rt.return_stack.pop();
}

fn execute(rt: *Runtime) Error!void {
    const cfa_addr = rt.data_stack.pop();
    rt.return_stack.push(rt.program_counter);
    rt.program_counter = cfa_addr;
}

fn jump(rt: *Runtime) Error!void {
    try rt.assertValidProgramCounter();
    const addr = rt.memory[rt.program_counter];
    rt.program_counter = addr;
}

fn jump0(rt: *Runtime) Error!void {
    try rt.assertValidProgramCounter();

    const conditional = rt.data_stack.pop();
    if (!runtime.isTruthy(conditional)) {
        try jump(rt);
    } else {
        try rt.advancePC(@sizeOf(Cell));
    }
}

fn quit(rt: *Runtime) Error!void {
    rt.program_counter = 0;
    rt.should_quit = true;
}

fn bye(rt: *Runtime) Error!void {
    rt.program_counter = 0;
    rt.should_bye = true;
}

fn eq(rt: *Runtime) Error!void {
    rt.data_stack.eq();
}

fn eq0(rt: *Runtime) Error!void {
    rt.data_stack.eq0();
}

fn gt(rt: *Runtime) Error!void {
    rt.data_stack.gt();
}

fn gteq(rt: *Runtime) Error!void {
    rt.data_stack.gteq();
}

fn lt(rt: *Runtime) Error!void {
    rt.data_stack.lt();
}

fn lteq(rt: *Runtime) Error!void {
    rt.data_stack.lteq();
}

fn and_(rt: *Runtime) Error!void {
    rt.data_stack.and_();
}

fn or_(rt: *Runtime) Error!void {
    rt.data_stack.ior();
}

fn xor(rt: *Runtime) Error!void {
    rt.data_stack.xor();
}

fn invert(rt: *Runtime) Error!void {
    rt.data_stack.invert();
}

fn lshift(rt: *Runtime) Error!void {
    rt.data_stack.lshift();
}

fn rshift(rt: *Runtime) Error!void {
    rt.data_stack.rshift();
}

fn inc(rt: *Runtime) Error!void {
    rt.data_stack.inc();
}

fn dec(rt: *Runtime) Error!void {
    rt.data_stack.dec();
}

fn drop(rt: *Runtime) Error!void {
    rt.data_stack.drop();
}

fn dup(rt: *Runtime) Error!void {
    rt.data_stack.dup();
}

fn swap(rt: *Runtime) Error!void {
    rt.data_stack.swap();
}

fn flip(rt: *Runtime) Error!void {
    rt.data_stack.flip();
}

fn over(rt: *Runtime) Error!void {
    rt.data_stack.over();
}

fn nip(rt: *Runtime) Error!void {
    rt.data_stack.nip();
}

fn tuck(rt: *Runtime) Error!void {
    rt.data_stack.tuck();
}

fn rot(rt: *Runtime) Error!void {
    rt.data_stack.rot();
}

fn nrot(rt: *Runtime) Error!void {
    rt.data_stack.nrot();
}

fn store(rt: *Runtime) Error!void {
    const addr, const value = rt.data_stack.pop2();
    try mem.writeCell(rt.memory, addr, value);
}

fn fetchAdd(rt: *Runtime) Error!void {
    const addr, const value = rt.data_stack.pop2();
    (try mem.cellPtr(rt.memory, addr)).* +%= value;
}

fn fetch(rt: *Runtime) Error!void {
    const addr = rt.data_stack.pop();
    rt.data_stack.push(try mem.readCell(rt.memory, addr));
}

fn comma(rt: *Runtime) Error!void {
    const value = rt.data_stack.pop();
    try rt.interpreter.dictionary.here.comma(value);
}

fn storeC(rt: *Runtime) Error!void {
    const addr, const value = rt.data_stack.pop2();
    const value_u8: u8 = @truncate(value);
    rt.memory[addr] = value_u8;
}

fn fetchAddC(rt: *Runtime) Error!void {
    const addr, const value = rt.data_stack.pop2();
    const value_u8: u8 = @truncate(value);
    rt.memory[addr] +%= value_u8;
}

fn fetchC(rt: *Runtime) Error!void {
    const addr = rt.data_stack.pop();
    rt.data_stack.push(rt.memory[addr]);
}

fn commaC(rt: *Runtime) Error!void {
    const value = rt.data_stack.pop();
    try rt.interpreter.dictionary.here.commaC(@truncate(value));
}

fn toR(rt: *Runtime) Error!void {
    rt.return_stack.push(rt.data_stack.pop());
}

fn fromR(rt: *Runtime) Error!void {
    rt.data_stack.push(rt.return_stack.pop());
}

fn fetchR(rt: *Runtime) Error!void {
    rt.data_stack.push(rt.return_stack.peek());
}

fn plus(rt: *Runtime) Error!void {
    rt.data_stack.add();
}

fn minus(rt: *Runtime) Error!void {
    rt.data_stack.subtract();
}

fn multiply(rt: *Runtime) Error!void {
    rt.data_stack.multiply();
}

fn divide(rt: *Runtime) Error!void {
    rt.data_stack.divide();
}

fn mod(rt: *Runtime) Error!void {
    rt.data_stack.mod();
}

fn find(rt: *Runtime) Error!void {
    const len, const addr = rt.data_stack.pop2();
    const word = try mem.constSliceFromAddrAndLen(rt.memory, addr, len);
    // TODO which wordlist should this use?
    const wordlist_idx = rt.interpreter.dictionary.context.fetch();
    if (try rt.interpreter.dictionary.search(wordlist_idx, word)) |word_info| {
        rt.data_stack.push(word_info.definition_addr);
        rt.data_stack.push(runtime.cellFromBoolean(true));
    } else {
        rt.data_stack.push(0);
        rt.data_stack.push(runtime.cellFromBoolean(false));
    }
}

fn nextWord(rt: *Runtime) Error!void {
    // TODO should this try to refill?
    const range = rt.input_buffer.readNextWordRange() orelse {
        return error.UnexpectedEndOfInput;
    };
    rt.data_stack.push(range.address);
    rt.data_stack.push(range.len);
}

fn define(rt: *Runtime) Error!void {
    const len, const addr = rt.data_stack.pop2();
    const word = try mem.constSliceFromAddrAndLen(rt.memory, addr, len);
    const wordlist_idx = rt.interpreter.dictionary.context.fetch();
    try rt.interpreter.dictionary.define(wordlist_idx, word);
}

fn nextChar(rt: *Runtime) Error!void {
    // TODO should this try to refill?
    const char = rt.input_buffer.readNextChar() orelse {
        return error.UnexpectedEndOfInput;
    };
    rt.data_stack.push(char);
}

fn refill(rt: *Runtime) Error!void {
    const did_refill = try rt.input_buffer.refill();
    rt.data_stack.push(runtime.cellFromBoolean(did_refill));
}

fn tick(rt: *Runtime) Error!void {
    // TODO should this try to refill?
    const word = rt.input_buffer.readNextWord() orelse {
        return error.UnexpectedEndOfInput;
    };
    const wordlist_idx = rt.interpreter.dictionary.context.fetch();
    if (try rt.interpreter.dictionary.search(wordlist_idx, word)) |word_info| {
        const cfa_addr = try rt.interpreter.dictionary.toCfa(word_info.definition_addr);
        rt.data_stack.push(cfa_addr);
    } else {
        // TODO
        @import("std").debug.print("word not found {}:{s}\n", .{ wordlist_idx, word });
        return error.WordNotFound;
    }
}

fn lit(rt: *Runtime) Error!void {
    try rt.assertValidProgramCounter();
    const value = try mem.readCell(rt.memory, rt.program_counter);
    rt.data_stack.push(value);
    try rt.advancePC(@sizeOf(Cell));
}
