const std = @import("std");

const vm = @import("mini.zig");
const utils = @import("utils.zig");

const bytecodes = @import("bytecodes.zig");
const Register = @import("register.zig").Register;

const base_terminator = 0b10000000;

const TerminatorReadError = error{
    Overflow,
} || vm.mem.MemoryError;

fn readUntilTerminator(
    memory: []const u8,
    str_start: vm.Cell,
) TerminatorReadError!vm.Cell {
    var str_at = str_start;
    while (str_at < memory.len) {
        if (memory[str_at] >= base_terminator) {
            return str_at;
        }
        str_at = try std.math.add(vm.Cell, str_at, 1);
    }
    return error.OutOfBounds;
}

fn compareStringUntilTerminator(
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
    if (utils.stringsEqual(str, to_compare)) {
        return str_end;
    } else {
        return null;
    }
}

/// This is a Forth style dictionary
///   where each definition has a pointer to the previous definition
pub fn Dictionary(
    comptime here_offset: vm.Cell,
    comptime latest_offset: vm.Cell,
) type {
    return struct {
        memory: vm.mem.CellAlignedMemory,
        here: Register(here_offset),
        latest: Register(latest_offset),

        pub fn initInOneMemoryBlock(
            self: *@This(),
            memory: vm.mem.CellAlignedMemory,
            // TODO could probably make this comptime
            dictionary_start: vm.Cell,
        ) vm.mem.MemoryError!void {
            self.memory = memory;
            try self.here.init(self.memory);
            try self.latest.init(self.memory);
            self.here.store(dictionary_start);
            self.latest.store(0);
        }

        pub fn lookup(
            self: @This(),
            word: []const u8,
        ) vm.Error!?vm.Cell {
            var latest = self.latest.fetch();
            while (latest != 0) {
                const terminator_addr = compareStringUntilTerminator(
                    self.memory,
                    latest + @sizeOf(vm.Cell),
                    word,
                ) catch |err| switch (err) {
                    // this won't happen with toTerminator
                    //   because we check name length when defining words
                    error.Overflow => unreachable,
                    else => |e| return e,
                };

                if (terminator_addr) |addr| {
                    // TODO read terminator
                    const terminator = (try vm.mem.cellAt(self.memory, addr)).*;
                    _ = terminator;
                    if (true) {
                        return latest;
                    }
                }
                // TODO maybe write register.deref();
                latest = try vm.mem.checkedRead(self.memory, latest);
            }
            return null;
        }

        pub fn toTerminator(
            self: @This(),
            addr: vm.Cell,
        ) vm.mem.MemoryError!vm.Cell {
            const terminator_addr = readUntilTerminator(
                self.memory,
                addr + @sizeOf(vm.Cell),
            ) catch |err| switch (err) {
                // this won't happen with toTerminator
                //   because we check name length when defining words
                error.Overflow => unreachable,
                else => |e| return e,
            };
            return terminator_addr;
        }

        pub fn toCfa(
            self: @This(),
            addr: vm.Cell,
        ) vm.mem.MemoryError!vm.Cell {
            return (try self.toTerminator(addr)) + 1;
        }

        pub fn defineWord(
            self: *@This(),
            name: []const u8,
        ) vm.Error!void {
            const previous_word_addr = self.latest.fetch();
            const aligned_here = self.here.alignForward(@alignOf(vm.Cell));
            try self.here.comma(self.memory, previous_word_addr);
            self.latest.store(aligned_here);

            if (name.len > std.math.maxInt(vm.Cell)) {
                return error.WordNameTooLong;
            }
            const cell_name_len = @as(vm.Cell, @intCast(name.len));
            const name_location = try vm.mem.sliceFromAddrAndLen(
                self.memory,
                self.here.fetch(),
                cell_name_len,
            );
            // TODO should check here that all the u8's in name are <127
            @memcpy(name_location, name);

            self.here.storeAdd(cell_name_len);
            try self.here.commaC(self.memory, 0b10000000);
        }

        pub fn compileLit(self: *@This(), value: vm.Cell) vm.mem.MemoryError!void {
            try self.here.commaC(self.memory, bytecodes.lookupBytecodeByName("lit") orelse unreachable);
            try self.here.commaByteAlignedCell(self.memory, value);
        }

        pub fn compileLitC(self: *@This(), value: u8) vm.mem.MemoryError!void {
            try self.here.commaC(self.memory, bytecodes.lookupBytecodeByName("litc") orelse unreachable);
            try self.here.commaC(self.memory, value);
        }

        // TODO write tests for these
        pub fn compileAbsJump(self: *@This(), addr: vm.Cell) vm.Error!void {
            if (addr > std.math.maxInt(u15)) {
                return error.InvalidAddress;
            }

            const base = @as(vm.Cell, bytecodes.base_abs_jump_bytecode) << 8;
            const jump = base | (addr & 0x7fff);
            try self.here.commaC(self.memory, @truncate(jump >> 8));
            try self.here.commaC(self.memory, @truncate(jump));
        }

        // TODO write tests for these
        pub fn compileData(self: *@This(), data: []u8) vm.Error!void {
            if (data.len > std.math.maxInt(u12)) {
                return error.InvalidAddress;
            }

            const base = @as(vm.Cell, bytecodes.base_data_bytecode) << 8;
            const data_len = base | @as(vm.Cell, @truncate(data.len & 0x0fff));
            try self.here.commaC(self.memory, @truncate(data_len >> 8));
            try self.here.commaC(self.memory, @truncate(data_len));
            for (data) |byte| {
                try self.here.commaC(self.memory, byte);
            }
        }

        pub fn compileConstant(
            self: *@This(),
            name: []const u8,
            value: vm.Cell,
        ) vm.Error!void {
            try self.defineWord(name);
            try self.compileLit(value);
            try self.here.commaC(self.memory, bytecodes.lookupBytecodeByName("exit") orelse unreachable);
        }
    };
}

test "dictionary" {
    const testing = @import("std").testing;

    const memory = try vm.mem.allocateCellAlignedMemory(
        testing.allocator,
        vm.max_memory_size,
    );
    defer testing.allocator.free(memory);

    const here_offset = 0;
    const latest_offset = 2;
    const dictionary_start = 16;

    var dictionary: Dictionary(here_offset, latest_offset) = undefined;
    try dictionary.initInOneMemoryBlock(
        memory,
        dictionary_start,
    );

    try dictionary.defineWord("name");

    try testing.expectEqual(
        dictionary.here.fetch() - dictionary_start,
        ((try dictionary.toTerminator(dictionary_start)) - dictionary_start) + 1,
    );

    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 0x00, 0x00, 'n', 'a', 'm', 'e', base_terminator },
        memory[dictionary_start..][0..7],
    );

    try dictionary.defineWord("hellow");

    try testing.expectEqual(dictionary_start, try dictionary.lookup("name"));
    try testing.expectEqual(
        null,
        try dictionary.lookup("wow"),
    );
}
