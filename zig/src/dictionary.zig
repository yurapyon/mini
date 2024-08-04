const std = @import("std");

const vm = @import("mini.zig");
const utils = @import("utils.zig");

const bytecodes = @import("bytecodes.zig");
const Register = @import("register.zig").Register;

// TODO rename this somehow
const t = @import("terminator.zig");

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
                const terminator_addr = t.compareStringUntilTerminator(
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
                    const terminator_byte = try vm.mem.checkedRead(self.memory, addr);
                    const terminator = t.TerminatorInfo.fromByte(terminator_byte);
                    if (!terminator.is_hidden) {
                        return latest;
                    } else {
                        std.debug.print("hidden word skipped: {s}\n", .{word});
                    }
                }
                latest = (try vm.mem.cellAt(self.memory, latest)).*;
            }
            return null;
        }

        pub fn toTerminator(
            self: @This(),
            addr: vm.Cell,
        ) vm.mem.MemoryError!vm.Cell {
            const terminator_addr = t.readUntilTerminator(
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

        pub fn getTerminator(
            self: @This(),
            addr: vm.Cell,
        ) vm.mem.MemoryError!t.TerminatorInfo {
            // NOTE
            // the next array access is ok because we've already checked
            //   for out of bounds errors in toTerminator
            const terminator_byte = self.memory[try self.toTerminator(addr)];
            return t.TerminatorInfo.fromByte(terminator_byte);
        }

        // TODO should this throw memory errors?
        fn alignSelf(self: *@This()) void {
            _ = self.here.alignForward(@alignOf(vm.Cell));
        }

        pub fn defineWord(
            self: *@This(),
            name: []const u8,
        ) vm.Error!void {
            for (name) |ch| {
                if (ch >= t.base_terminator) {
                    return error.WordNameInvalid;
                }
            }

            self.alignSelf();

            const definition_start = self.here.fetch();
            const previous_word_addr = self.latest.fetch();

            self.latest.store(definition_start);
            try self.here.comma(self.memory, previous_word_addr);

            try self.here.commaString(name);

            const header_size = name.len + 3;
            const need_to_align = (definition_start + header_size) % 2 == 1;
            if (need_to_align) {
                try self.here.commaC(self.memory, 0);
            }

            try self.here.commaC(self.memory, t.base_terminator);
        }

        pub fn compileLit(self: *@This(), value: vm.Cell) vm.mem.MemoryError!void {
            try self.here.commaC(self.memory, bytecodes.lookupBytecodeByName("lit") orelse unreachable);
            try self.here.commaByteAlignedCell(self.memory, value);
        }

        pub fn compileLitC(self: *@This(), value: u8) vm.mem.MemoryError!void {
            try self.here.commaC(self.memory, bytecodes.lookupBytecodeByName("litc") orelse unreachable);
            try self.here.commaC(self.memory, value);
        }

        // TODO rename this
        pub fn compileAbsJump(self: *@This(), addr: vm.Cell) vm.Error!void {
            try self.here.commaC(self.memory, bytecodes.lookupBytecodeByName("call") orelse unreachable);
            try self.here.commaByteAlignedCell(self.memory, addr);
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

        pub fn iterator(self: *@This()) utils.LinkedListIterator {
            return utils.LinkedListIterator.from(self.memory, self.latest.fetch());
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
        &[_]u8{ 0x00, 0x00, 'n', 'a', 'm', 'e', t.base_terminator },
        memory[dictionary_start..][0..7],
    );

    try dictionary.defineWord("hellow");

    try testing.expectEqual(dictionary_start, try dictionary.lookup("name"));
    try testing.expectEqual(null, try dictionary.lookup("wow"));

    const noname_addr = dictionary.here.alignForward(@alignOf(vm.Cell));
    try dictionary.defineWord("");
    try testing.expectEqual(dictionary_start, try dictionary.lookup("name"));
    try testing.expectEqual(null, try dictionary.lookup("wow"));

    try testing.expectEqual(noname_addr, try dictionary.lookup(""));
}
