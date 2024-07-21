const vm = @import("MiniVM.zig");

fn nop(_: *vm.MiniVM) vm.Error!void {}

fn dup(mini: *vm.MiniVM) vm.Error!void {
    try mini.data_stack.dup();
}

fn drop(mini: *vm.MiniVM) vm.Error!void {
    try mini.data_stack.drop();
}

fn swap(mini: *vm.MiniVM) vm.Error!void {
    try mini.data_stack.swap();
}

pub const lookup_table = [_]vm.BytecodeFn{
    nop,
    nop,
    nop,
    nop,

    nop,
    nop,
    nop,
    nop,

    nop,
    nop,
    nop,
    nop,

    nop,
    nop,
    nop,
    nop,

    // ===
    nop,
    nop,
    nop,
    nop,

    nop,
    nop,
    nop,
    nop,

    nop,
    nop,
    nop,
    nop,

    nop,
    nop,
    nop,
    nop,

    // ===
    nop,
    nop,
    nop,
    nop,

    nop,
    nop,
    nop,
    nop,

    nop,
    nop,
    nop,
    nop,

    nop,
    nop,
    nop,
    nop,

    // ===
    dup,
    drop,
    swap,
    nop,

    nop,
    nop,
    nop,
    nop,

    nop,
    nop,
    nop,
    nop,

    nop,
    nop,
    nop,
    nop,

    // ===
    nop,
    nop,
    nop,
    nop,

    nop,
    nop,
    nop,
    nop,

    nop,
    nop,
    nop,
    nop,

    nop,
    nop,
    nop,
    nop,

    // ===
    nop,
    nop,
    nop,
    nop,

    nop,
    nop,
    nop,
    nop,

    nop,
    nop,
    nop,
    nop,

    nop,
    nop,
    nop,
    nop,

    // ===
    nop,
    nop,
    nop,
    nop,

    nop,
    nop,
    nop,
    nop,

    nop,
    nop,
    nop,
    nop,

    nop,
    nop,
    nop,
    nop,
};
