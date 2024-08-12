const std = @import("std");

const vm = @import("mini.zig");

const Register = @import("register.zig").Register;

pub fn isWhitespace(char: u8) bool {
    return char == ' ' or char == '\n';
}

// TODO turn this into a device instead

// TODO could have a Refiller struct

/// Forth-style input:
///   i.e. line-by-line input from a buffer
//         ability to read from stdin if no buffer is supplied (TODO)
pub fn InputSource(comptime buffer_at_offset: vm.Cell, comptime buffer_len_offset: vm.Cell) type {
    return struct {
        // TODO should this return an optional?
        pub const RefillFn = *const fn (userdata: *anyopaque) vm.InputError!?[]const u8;
        // TODO could make this 80 instead of 128
        const max_buffer_len = 128;
        pub const MemType = [max_buffer_len]u8;

        _memory: vm.mem.CellAlignedMemory,
        // TODO this should be comptime too i think
        _buffer_offset: vm.Cell,
        buffer_len: Register(buffer_len_offset),
        buffer_at: Register(buffer_at_offset),
        refill_fn: ?RefillFn,
        refill_userdata: ?*anyopaque,

        pub fn initInOneMemoryBlock(
            self: *@This(),
            memory: vm.mem.CellAlignedMemory,
            buffer_offset: vm.Cell,
        ) vm.mem.MemoryError!void {
            self._memory = memory;
            self._buffer_offset = buffer_offset;
            try self.buffer_len.init(self._memory);
            try self.buffer_at.init(self._memory);

            self.buffer_len.store(0);
            self.buffer_at.store(0);

            self.refill_fn = null;
            self.refill_userdata = null;
        }

        // TODO maybe make this private ?
        pub fn setInputBuffer(self: *@This(), buffer: []const u8) (vm.InputError || vm.mem.MemoryError)!void {
            if (buffer.len > max_buffer_len) {
                return error.OversizeInputBuffer;
            }
            const mem_slice = try vm.mem.sliceFromAddrAndLen(
                self._memory,
                self._buffer_offset,
                buffer.len,
            );
            @memcpy(mem_slice, buffer);
            self.buffer_at.store(0);
            self.buffer_len.store(@truncate(buffer.len));
        }

        pub fn setRefillCallback(
            self: *@This(),
            refill_fn: RefillFn,
            userdata: *anyopaque,
        ) void {
            self.refill_fn = refill_fn;
            self.refill_userdata = userdata;
        }

        pub fn readNextChar(self: *@This()) ?u8 {
            const buffer_at = self.buffer_at.fetch();
            const buffer_len = self.buffer_len.fetch();
            if (buffer_at < buffer_len) {
                const ret = self._memory[self._buffer_offset + buffer_at];
                self.buffer_at.storeAdd(1);
                return ret;
            } else {
                return null;
            }
        }

        fn skipWhitespace(self: *@This()) ?u8 {
            var char = self.readNextChar() orelse return null;
            while (isWhitespace(char)) {
                char = self.readNextChar() orelse return null;
            }
            return char;
        }

        pub fn readNextWordRange(self: *@This()) ?struct {
            address: vm.Cell,
            len: vm.Cell,
        } {
            var char = self.skipWhitespace() orelse return null;

            const word_start = self.buffer_at.fetch() - 1;

            while (true) {
                char = self.readNextChar() orelse break;
                if (isWhitespace(char)) {
                    self.buffer_at.storeSubtract(1);
                    break;
                }
            }

            const word_end = self.buffer_at.fetch();
            return .{
                .address = self._buffer_offset + word_start,
                .len = word_end - word_start,
            };
        }

        pub fn readNextWord(self: *@This()) ?[]const u8 {
            const range = self.readNextWordRange() orelse return null;
            // TODO we should write a test to make sure that this won't happen
            return vm.mem.sliceFromAddrAndLen(
                self._memory,
                range.address,
                range.len,
            ) catch unreachable;
        }

        pub fn refill(
            self: *@This(),
        ) (vm.InputError || vm.mem.MemoryError)!bool {
            const refill_fn = self.refill_fn orelse return error.CannotRefill;
            const userdata = self.refill_userdata orelse return error.CannotRefill;
            const buffer = try refill_fn(userdata);
            if (buffer) |buf| {
                try self.setInputBuffer(buf);
                return true;
            } else {
                return false;
            }
        }
    };
}

test "input-sources" {
    const testing = @import("std").testing;

    const memory = try vm.mem.allocateCellAlignedMemory(
        testing.allocator,
        vm.max_memory_size,
    );
    defer testing.allocator.free(memory);

    const buffer_offset = 4;
    const at_offset = 0;
    const len_offset = 2;

    var input_source: InputSource(at_offset, len_offset) = undefined;
    try input_source.initInOneMemoryBlock(
        memory,
        buffer_offset,
    );
    const refill_str = "refill";
    input_source.setRefillCallback(testRefill, @ptrCast(@constCast(&@as([]const u8, refill_str))));

    try input_source.setInputBuffer("asdf wowo hellow");

    try testing.expectEqual('a', input_source.readNextChar());
    try testing.expectEqual('s', input_source.readNextChar());
    try testing.expectEqual('d', input_source.readNextChar());
    try testing.expectEqual('f', input_source.readNextChar());

    try testing.expectEqualSlices(
        u8,
        "wowo",
        input_source.readNextWord() orelse return error.OutOfInput,
    );

    _ = try input_source.refill();

    try testing.expectEqualSlices(
        u8,
        "refill",
        input_source.readNextWord() orelse return error.OutOfInput,
    );
}

fn testRefill(userdata: *anyopaque) vm.InputError!?[]const u8 {
    const str: *[]const u8 = @ptrCast(@alignCast(userdata));
    return str.*;
}