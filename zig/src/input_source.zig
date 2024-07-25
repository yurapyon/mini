const std = @import("std");

const vm = @import("mini.zig");

const Register = @import("register.zig").Register;

pub fn isWhitespace(char: u8) bool {
    return char == ' ' or char == '\n';
}

// TODO turn this into a device instead

/// Forth-style input:
///   i.e. line-by-line input from a buffer
//         ability to read from stdin if no buffer is supplied (TODO)
pub const InputSource = struct {
    pub const RefillFn = *const fn () vm.InputError![]const u8;
    const max_buffer_len = 128;
    pub const MemType = [max_buffer_len]u8;

    memory: vm.Memory,
    buffer_offset: vm.Cell,
    buffer_len: Register,
    buffer_at: Register,
    refill_fn: ?RefillFn,

    pub fn init(
        self: *@This(),
        memory: vm.Memory,
        buffer_offset: vm.Cell,
        buffer_at_offset: vm.Cell,
        buffer_len_offset: vm.Cell,
    ) void {
        self.memory = memory;
        self.buffer_offset = buffer_offset;
        self.buffer_len.init(self.memory, buffer_len_offset);
        self.buffer_at.init(self.memory, buffer_at_offset);

        self.buffer_len.store(0);
        self.buffer_at.store(0);

        self.refill_fn = null;
    }

    pub fn setInputBuffer(self: *@This(), buffer: []const u8) void {
        // TODO make sure buffer.len isn't too big
        const mem_slice = vm.sliceFromAddrAndLen(
            self.memory,
            self.buffer_offset,
            buffer.len,
        );
        std.mem.copyForwards(u8, mem_slice, buffer);
        self.buffer_at.store(0);
        self.buffer_len.store(@truncate(buffer.len));
    }

    pub fn readNextChar(self: *@This()) vm.InputError!?u8 {
        const buffer_at = self.buffer_at.fetch();
        if (buffer_at < self.buffer_len.fetch()) {
            const ret = self.memory[self.buffer_offset + buffer_at];
            self.buffer_at.storeAdd(1);
            return ret;
        } else {
            return null;
        }
    }

    fn skipWhitespace(self: *@This()) vm.InputError!?u8 {
        var char = try self.readNextChar() orelse return null;
        while (isWhitespace(char)) {
            char = (try self.readNextChar()) orelse return null;
        }
        return char;
    }

    pub fn readNextWordRange(self: *@This()) vm.InputError!?struct {
        address: vm.Cell,
        len: vm.Cell,
    } {
        var char = try self.skipWhitespace() orelse return null;

        const word_start = self.buffer_at.fetch() - 1;

        while (true) {
            char = (try self.readNextChar()) orelse break;
            if (isWhitespace(char)) {
                self.buffer_at.storeSubtract(1);
                break;
            }
        }

        const word_end = self.buffer_at.fetch();
        return .{
            .address = self.buffer_offset + word_start,
            .len = word_end - word_start,
        };
    }

    pub fn readNextWord(self: *@This()) vm.InputError!?[]const u8 {
        const range = try self.readNextWordRange() orelse return null;
        return vm.sliceFromAddrAndLen(self.memory, range.address, range.len);
    }

    pub fn refill(
        self: *@This(),
    ) vm.InputError!void {
        if (self.refill_fn) |refill_fn| {
            const buffer = try refill_fn();
            self.setInputBuffer(buffer);
        } else {
            return error.CannotRefill;
        }
    }
};

test "input-sources" {
    const testing = @import("std").testing;

    const mem = try vm.allocateMemory(testing.allocator);
    defer testing.allocator.free(mem);

    const buffer_offset = 4;
    const at_offset = 0;
    const len_offset = 2;

    var input_source: InputSource = undefined;
    input_source.init(
        mem,
        buffer_offset,
        at_offset,
        len_offset,
    );
    input_source.refill_fn = testRefill;

    input_source.setInputBuffer("asdf wowo hellow");

    try testing.expectEqual('a', try input_source.readNextChar());
    try testing.expectEqual('s', try input_source.readNextChar());
    try testing.expectEqual('d', try input_source.readNextChar());
    try testing.expectEqual('f', try input_source.readNextChar());

    try testing.expectEqualSlices(
        u8,
        "wowo",
        try input_source.readNextWord() orelse return error.OutOfInput,
    );

    try input_source.refill();

    try testing.expectEqualSlices(
        u8,
        "refill",
        try input_source.readNextWord() orelse return error.OutOfInput,
    );
}

fn testRefill() vm.InputError![]const u8 {
    return "refill";
}
