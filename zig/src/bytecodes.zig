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

fn dup(mini: *vm.MiniVM) vm.Error!void {
    try mini.data_stack.dup();
}

fn drop(mini: *vm.MiniVM) vm.Error!void {
    try mini.data_stack.drop();
}

fn swap(mini: *vm.MiniVM) vm.Error!void {
    try mini.data_stack.swap();
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

    .{ .name = "lshift", .callback = nop },
    .{ .name = "rshift", .callback = nop },
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

    .{ .name = "rot", .callback = nop },
    .{ .name = "-rot", .callback = nop },
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

    .{ .name = "0", .callback = nop },
    .{ .name = "0xffff", .callback = nop },

    .{ .name = "1", .callback = nop },
    .{ .name = "2", .callback = nop },
    .{ .name = "4", .callback = nop },
    .{ .name = "8", .callback = nop },

    .{ .name = "cell>bytes", .callback = nop },
    .{ .name = "bytes>cell", .callback = nop },

    // ===
    .{ .name = "cmove<", .callback = nop },
    .{ .name = "cmove>", .callback = nop },
    .{ .name = "mem=", .callback = nop },

    .{ .name = "?dup", .callback = nop },

    .{ .name = "nip", .callback = nop },
    .{ .name = "flip", .callback = nop },
    .{ .name = "tuck", .callback = nop },
    .{ .name = "over", .callback = nop },

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
