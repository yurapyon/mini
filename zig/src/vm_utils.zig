const std = @import("std");

const vm = @import("mini.zig");

pub fn printWordBody(
    memory: vm.mem.CellAlignedMemory,
    cfa: vm.Cell,
    next_word: vm.Cell,
) void {
    std.debug.print(".", .{});
    for (memory[cfa..next_word]) |byte| {
        std.debug.print("{x:0>2}.", .{byte});
    }
}

pub fn printMemory(mini: *vm.MiniVM) !void {
    var dictionary_iter = mini.dictionary.iterator();

    const current_latest = mini.dictionary.latest.fetch();
    var previous_addr = try mini.dictionary.toTerminator(current_latest) + 20;

    while (try dictionary_iter.next()) |addr| {
        const terminator_addr = try mini.dictionary.toTerminator(addr);

        const name = try vm.mem.sliceFromAddrAndLen(
            mini.dictionary.memory,
            addr + 2,
            terminator_addr - (addr + 2),
        );

        const terminator = mini.memory[terminator_addr];
        const is_immediate = terminator & 0b01000000 > 0;
        const is_hidden = terminator & 0b00100000 > 0;

        const cutoff_name = if (name[name.len - 1] == 0) name[0 .. name.len - 1] else name;

        std.debug.print("{s}{s}{x:0>4}: {s}\t{s}", .{
            if (is_immediate) "i" else " ",
            if (is_hidden) "h" else " ",
            addr,
            cutoff_name,
            if (cutoff_name.len >= 8) "" else "\t",
        });
        printWordBody(mini.memory, terminator_addr + 1, previous_addr);
        std.debug.print("\n", .{});

        previous_addr = addr;
    }
}
