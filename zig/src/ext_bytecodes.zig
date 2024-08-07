const std = @import("std");

const vm = @import("mini.zig");
const vm_utils = @import("vm_utils.zig");

pub fn defineAll(
    mini: *vm.MiniVM,
) vm.Error!void {
    // TODO error if lookup_table is too big
    for (lookup_table, 0..) |definition, i| {
        try mini.dictionary.compileExternal(definition.name, @intCast(i));
    }
}

pub fn executeExt(
    shortcode: vm.Cell,
    mini: *vm.MiniVM,
    ctx: vm.ExecutionContext,
) vm.Error!void {
    if (shortcode < lookup_table.len) {
        try lookup_table[shortcode].callback(mini, ctx, null);
    } else {
        std.debug.print("EXT .{x:0>4}\n", .{shortcode});
    }
}

// ===

const ExternalDefinition = struct {
    name: []const u8,
    callback: vm.ExternalFn,
};

fn constructBasicExternal(name: []const u8, callback: vm.ExternalFn) ExternalDefinition {
    return .{
        .name = name,
        .callback = callback,
    };
}

const lookup_table = [_]ExternalDefinition{
    constructBasicExternal("##.s", printStack),
    constructBasicExternal("##break", miniBreakpoint),
    constructBasicExternal("##type", printString),
    constructBasicExternal("##cr", printNewline),
    constructBasicExternal("##.d", printDictionary),
};

fn printStack(mini: *vm.MiniVM, _: vm.ExecutionContext, _: ?*anyopaque) vm.Error!void {
    _ = mini;
    // TODO
    //     std.debug.print("stack ==\n", .{});
    //     for (try mini.data_stack.asSlice(), 0..) |cell, i| {
    //         std.debug.print("{}: {}\n", .{ i, cell });
    //     }
}

fn miniBreakpoint(_: *vm.MiniVM, _: vm.ExecutionContext, _: ?*anyopaque) vm.Error!void {
    _ = 2 + 2;
}

fn printString(mini: *vm.MiniVM, _: vm.ExecutionContext, _: ?*anyopaque) vm.Error!void {
    const len, const addr = try mini.data_stack.popMultiple(2);
    const str = try vm.mem.constSliceFromAddrAndLen(mini.memory, addr, len);
    std.debug.print("{s}", .{str});
}

fn printNewline(_: *vm.MiniVM, _: vm.ExecutionContext, _: ?*anyopaque) vm.Error!void {
    std.debug.print("\n", .{});
}

fn printDictionary(mini: *vm.MiniVM, _: vm.ExecutionContext, _: ?*anyopaque) vm.Error!void {
    try vm_utils.printDictionary(mini);
}
