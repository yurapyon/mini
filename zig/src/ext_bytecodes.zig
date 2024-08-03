const std = @import("std");

const vm = @import("mini.zig");
const vm_utils = @import("vm_utils.zig");

pub fn executeExt(
    shortcode: vm.Cell,
    mini: *vm.MiniVM,
    ctx: vm.ExecutionContext,
) vm.Error!void {
    if (shortcode < ext_lookup.len) {
        try ext_lookup[shortcode](mini, ctx);
    } else {
        std.debug.print("EXT .{x:0>4}\n", .{shortcode});
    }
}

const ExtFn = *const fn (
    mini: *vm.MiniVM,
    ctx: vm.ExecutionContext,
) vm.Error!void;

const ext_lookup = [_]ExtFn{
    printStack,
    miniBreakpoint,
    printString,
    printNewline,
    printDictionary,
};

fn printStack(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    std.debug.print("stack ==\n", .{});
    for (try mini.data_stack.asSlice(), 0..) |cell, i| {
        std.debug.print("{}: {}\n", .{ i, cell });
    }
}

fn miniBreakpoint(_: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    _ = 2 + 2;
}

fn printString(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    const len, const addr = try mini.data_stack.popMultiple(2);
    const str = try vm.mem.constSliceFromAddrAndLen(mini.memory, addr, len);
    std.debug.print("{s}", .{str});
}

fn printNewline(_: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    std.debug.print("\n", .{});
}

fn printDictionary(mini: *vm.MiniVM, _: vm.ExecutionContext) vm.Error!void {
    try vm_utils.printDictionary(mini);
}
