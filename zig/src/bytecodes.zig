const mem = @import("mem");

const vm = @import("MiniVM.zig");

const NamedCallback = struct {
    name: []const u8,
    callback: vm.BytecodeFn,
};

fn nop(_: *vm.MiniVM) vm.Error!void {}

fn store(mini: *vm.MiniVM) vm.Error!void {
    const addr, const value = try mini.data_stack.popCount(2);
    const mem_ptr = try vm.cellAccess(mini.memory, addr);
    mem_ptr.* = value;
}

fn storeAdd(mini: *vm.MiniVM) vm.Error!void {
    const addr, const value = try mini.data_stack.popCount(2);
    const mem_ptr = try vm.cellAccess(mini.memory, addr);
    mem_ptr.* +%= value;
}

fn fetch(mini: *vm.MiniVM) vm.Error!void {
    const addr = try mini.data_stack.pop();
    const mem_ptr = try vm.cellAccess(mini.memory, addr);
    try mini.data_stack.push(mem_ptr.*);
}

fn storeC(mini: *vm.MiniVM) vm.Error!void {
    const addr, const value = try mini.data_stack.popCount(2);
    const byte: u8 = @truncate(value);
    mini.memory[addr] = byte;
}

fn storeAddC(mini: *vm.MiniVM) vm.Error!void {
    const addr, const value = try mini.data_stack.popCount(2);
    const byte: u8 = @truncate(value);
    mini.memory[addr] +%= byte;
}

fn fetchC(mini: *vm.MiniVM) vm.Error!void {
    const addr = try mini.data_stack.pop();
    try mini.data_stack.push(mini.memory[addr]);
}

fn lshift(mini: *vm.MiniVM) vm.Error!void {
    const value, const shift_ = try mini.data_stack.popCount(2);
    try mini.data_stack.push(value << @truncate(shift_));
}

fn rshift(mini: *vm.MiniVM) vm.Error!void {
    const value, const shift_ = try mini.data_stack.popCount(2);
    try mini.data_stack.push(value >> @truncate(shift_));
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
    const value = try mini.data_stack.pop();
    const low = @as(u8, @truncate(value));
    const high = @as(u8, @truncate(value >> 8));
    try mini.data_stack.push(low);
    try mini.data_stack.push(high);
}

fn bytesToCell(mini: *vm.MiniVM) vm.Error!void {
    const low, const high = try mini.data_stack.popCount(2);
    const low_byte = @as(u8, @truncate(low));
    const high_byte = @as(u8, @truncate(high));
    const value = low_byte | (@as(vm.Cell, high_byte) << 8);
    try mini.data_stack.push(value);
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
    .{ .name = "exit", .callback = nop },
    .{ .name = "quit", .callback = nop },
    .{ .name = "panic", .callback = nop },
    .{ .name = "bye", .callback = nop },

    .{ .name = "'", .callback = nop },
    .{ .name = "[']", .callback = nop },
    .{ .name = "]", .callback = nop },
    .{ .name = "[", .callback = nop },

    .{ .name = "find", .callback = nop },
    .{ .name = "word", .callback = nop },
    .{ .name = "next-char", .callback = nop },
    .{ .name = "define", .callback = nop },

    .{ .name = "jump", .callback = nop },
    .{ .name = "branch", .callback = nop },
    .{ .name = "branch0", .callback = nop },
    .{ .name = "execute", .callback = nop },

    // ===
    .{ .name = "!", .callback = store },
    .{ .name = "+!", .callback = storeAdd },
    .{ .name = "@", .callback = fetch },
    .{ .name = ",", .callback = nop },
    .{ .name = "lit", .callback = nop },

    .{ .name = "c!", .callback = storeC },
    .{ .name = "+c!", .callback = storeAddC },
    .{ .name = "c@", .callback = fetchC },
    .{ .name = "c,", .callback = nop },
    .{ .name = "litc", .callback = nop },

    .{ .name = ">r", .callback = nop },
    .{ .name = "r>", .callback = nop },
    .{ .name = "r@", .callback = nop },

    .{ .name = "=", .callback = nop },
    .{ .name = "<", .callback = nop },
    .{ .name = "<=", .callback = nop },

    // ===
    .{ .name = "+", .callback = nop },
    .{ .name = "-", .callback = nop },
    .{ .name = "*", .callback = nop },
    .{ .name = "/mod", .callback = nop },
    .{ .name = "u/mod", .callback = nop },
    .{ .name = "negate", .callback = nop },

    .{ .name = "lshift", .callback = lshift },
    .{ .name = "rshift", .callback = rshift },
    .{ .name = "and", .callback = nop },
    .{ .name = "or", .callback = nop },
    .{ .name = "xor", .callback = nop },
    .{ .name = "invert", .callback = nop },

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
    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },

    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },

    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },

    // ===
    .{ .name = "0=", .callback = nop },
    .{ .name = ">", .callback = nop },
    .{ .name = ">=", .callback = nop },

    .{ .name = "here!", .callback = nop },
    .{ .name = "here+!", .callback = nop },
    .{ .name = "here@", .callback = nop },

    .{ .name = "1+", .callback = nop },
    .{ .name = "1-", .callback = nop },

    .{ .name = "0", .callback = push0 },
    .{ .name = "0xffff", .callback = pushFFFF },

    .{ .name = "1", .callback = push1 },
    .{ .name = "2", .callback = push2 },
    .{ .name = "4", .callback = push4 },
    .{ .name = "8", .callback = push8 },

    .{ .name = "cell>bytes", .callback = cellToBytes },
    .{ .name = "bytes>cell", .callback = bytesToCell },

    // ===
    .{ .name = "cmove<", .callback = nop },
    .{ .name = "cmove>", .callback = nop },
    .{ .name = "mem=", .callback = nop },

    .{ .name = "?dup", .callback = maybeDup },

    .{ .name = "nip", .callback = nip },
    .{ .name = "flip", .callback = flip },
    .{ .name = "tuck", .callback = tuck },
    .{ .name = "over", .callback = over },

    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },

    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },

    // ===
    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },

    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },

    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },

    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },
    .{ .name = "", .callback = nop },
};

pub fn getCallbackById(id: u8) NamedCallback {
    return lookup_table[id];
}

pub fn getCallbackByName(name: []u8) ?NamedCallback {
    for (lookup_table) |named_callback| {
        const eql = mem.eql(named_callback.name, name);
        if (eql) {
            return named_callback;
        }
    }
    return null;
}
