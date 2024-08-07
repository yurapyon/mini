const std = @import("std");

const vm = @import("mini.zig");
const utils = @import("utils.zig");

pub const base_terminator = 0b10000000;

const TerminatorReadError = error{
    Overflow,
} || vm.mem.MemoryError;

/// starting at str_start, return the address of the next terminator
pub fn readUntilTerminator(
    memory: []const u8,
    str_start: vm.Cell,
) TerminatorReadError!vm.Cell {
    var str_at = str_start;
    while (str_at < memory.len) {
        const byte = memory[str_at];
        if ((byte & 0b10000000) > 0) {
            return str_at;
        }
        str_at = try std.math.add(vm.Cell, str_at, 1);
    }
    return error.OutOfBounds;
}

fn maybeCutoffZeroTerminator(string: []const u8) []const u8 {
    if (string.len > 0 and string[string.len - 1] == 0) {
        return string[0..(string.len - 1)];
    } else {
        return string;
    }
}

pub fn compareStringUntilTerminator(
    memory: []const u8,
    str_start: vm.Cell,
    to_compare: []const u8,
) TerminatorReadError!?vm.Cell {
    // NOTE
    // to make this easy,
    //   just going to get a slice by reading until the terminator
    // then comparing the slices
    // it's possible to write an optimized version that only has to loop once
    //   but thats just O(n) vs O(2n) and not a big deal
    const str_end = try readUntilTerminator(memory, str_start);
    const str_len = str_end - str_start;
    const str = try vm.mem.constSliceFromAddrAndLen(memory, str_start, str_len);

    const lookup = maybeCutoffZeroTerminator(str);
    if (utils.stringsEqual(lookup, to_compare)) {
        return str_end;
    } else {
        return null;
    }
}

pub const TerminatorInfo = packed struct(u8) {
    padding: u6,
    is_immediate: bool,
    terminator_indicator: u1,

    pub fn fromByte(terminator_byte: u8) @This() {
        return @bitCast(terminator_byte);
    }
};
