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
    comptime context_offset: vm.Cell,
    comptime wordlists_offset: vm.Cell,
) type {
    return struct {
        memory: vm.mem.CellAlignedMemory,
        here: Register(here_offset),
        latest: Register(latest_offset),
        context: Register(context_offset),
        wordlists: Register(wordlists_offset),

        pub fn initInOneMemoryBlock(
            self: *@This(),
            memory: vm.mem.CellAlignedMemory,
            // TODO could probably make this comptime
            dictionary_start: vm.Cell,
        ) vm.mem.MemoryError!void {
            try vm.mem.assertCellMemoryAccess(memory, wordlists_offset + @sizeOf(vm.Cell));
            self.memory = memory;
            try self.here.init(self.memory);
            try self.context.init(self.memory);
            try self.latest.init(self.memory);
            try self.wordlists.init(self.memory);
            self.here.store(dictionary_start);
            self.latest.store(0);
            self.context.store(@intFromEnum(vm.CompileContext.forth));
            self.wordlists.storeWithOffset(0, 0) catch unreachable;
            self.wordlists.storeWithOffset(@sizeOf(vm.Cell), 0) catch unreachable;
        }

        pub fn lookup(
            self: @This(),
            wordlist_idx: vm.Cell,
            word: []const u8,
        ) vm.Error!?struct { addr: vm.Cell, wordlist_idx: vm.Cell } {
            // TODO invalid wordlist error
            var wordlists_at = wordlist_idx;
            while (true) {
                var latest = try self.wordlists.fetchWithOffset(
                    wordlists_at * @sizeOf(vm.Cell),
                );
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

                    if (terminator_addr) |_| {
                        return .{
                            .addr = latest,
                            .wordlist_idx = wordlists_at,
                        };
                    }
                    latest = (try vm.mem.cellAt(self.memory, latest)).*;
                }

                if (wordlists_at == 0) {
                    break;
                } else {
                    wordlists_at -= 1;
                }
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

            const context = @as(vm.CompileContext, @enumFromInt(self.context.fetch()));
            const previous_word_addr = switch (context) {
                .forth => self.wordlists.fetchWithOffset(0) catch unreachable,
                .compiler => self.wordlists.fetchWithOffset(
                    @sizeOf(vm.Cell),
                ) catch unreachable,
                // TODO error
                else => unreachable,
            };

            self.latest.store(definition_start);
            switch (context) {
                .forth => self.wordlists.storeWithOffset(0, definition_start) catch unreachable,
                .compiler => self.wordlists.storeWithOffset(
                    @sizeOf(vm.Cell),
                    definition_start,
                ) catch unreachable,
                // TODO error
                else => unreachable,
            }

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

        pub fn compileExternal(
            self: *@This(),
            name: []const u8,
            id: vm.Cell,
        ) vm.Error!void {
            const ext_tag = bytecodes.lookupBytecodeByName("ext") orelse unreachable;
            const exit_tag = bytecodes.lookupBytecodeByName("exit") orelse unreachable;
            try self.defineWord(name);
            try self.here.commaC(self.memory, ext_tag);
            try self.here.commaByteAlignedCell(self.memory, id);
            try self.here.commaC(self.memory, exit_tag);
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
