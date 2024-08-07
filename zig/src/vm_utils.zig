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

pub fn printDictionary(mini: *vm.MiniVM) !void {
    // TODO
    _ = mini;
    //     var dictionary_iter = mini.dictionary.iterator();
    //
    //     var previous_addr = mini.dictionary.here.fetch();
    //
    //     while (try dictionary_iter.next()) |addr| {
    //         const terminator_addr = try mini.dictionary.toTerminator(addr);
    //
    //         const name = try vm.mem.sliceFromAddrAndLen(
    //             mini.dictionary.memory,
    //             addr + 2,
    //             terminator_addr - (addr + 2),
    //         );
    //
    //         const terminator = mini.memory[terminator_addr];
    //         const terminator_info = TerminatorInfo.fromByte(terminator);
    //
    //         const cutoff_name = if (name[name.len - 1] == 0) name[0 .. name.len - 1] else name;
    //
    //         std.debug.print("{s}{x:0>4}: {s}\t{s}", .{
    //             if (terminator_info.is_immediate) "i" else " ",
    //             addr,
    //             cutoff_name,
    //             if (cutoff_name.len >= 8) "" else "\t",
    //         });
    //         printWordBody(mini.memory, terminator_addr + 1, previous_addr);
    //         std.debug.print("\n", .{});
    //
    //         previous_addr = addr;
    //     }
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
