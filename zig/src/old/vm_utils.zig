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

// TODO this is kinda broken because we dont handle having two wordlists
pub fn printDictionary(mini: *vm.MiniVM) !void {
    var dictionary_iter = mini.dictionary.iterator();

    var previous_addr = mini.dictionary.here.fetch();

    while (try dictionary_iter.next()) |addr| {
        const name_len_addr = addr + 2;
        const name_addr = name_len_addr + 1;
        const name_len = mini.dictionary.memory[name_len_addr];
        const name = try vm.mem.sliceFromAddrAndLen(
            mini.dictionary.memory,
            name_addr,
            name_len,
        );

        std.debug.print("{x:0>4}: {s}\t{s}{s}", .{
            addr,
            name,
            if (name.len <= 1) "\t" else "",
            if (name.len <= 9) "\t" else "",
        });
        const cfa_addr = try mini.dictionary.toCfa(addr);
        printWordBody(mini.memory, cfa_addr, previous_addr);
        std.debug.print("\n", .{});

        previous_addr = addr;
    }
}

// TODO currenly unused, should format more nicely
fn printMemoryStat(comptime name: []const u8) void {
    std.debug.print("{s}: {}\n", .{ name, vm.MemoryLayout.offsetOf(name) });
}

// TODO currenly unused, should format more nicely
fn printMemoryStats() void {
    printMemoryStat("here");
    printMemoryStat("latest");
    printMemoryStat("state");
    printMemoryStat("base");
}
