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
pub const InputSource = struct {
    pub const Error = vm.InputError || Register.Error;

    // TODO should this return an optional?
    pub const RefillFn = *const fn (userdata: *anyopaque) vm.InputError![]const u8;
    const max_buffer_len = 128;
    pub const MemType = [max_buffer_len]u8;

    memory: vm.Memory,
    buffer_offset: vm.Cell,
    buffer_len: Register,
    buffer_at: Register,
    refill_fn: ?RefillFn,
    refill_userdata: ?*anyopaque,

    pub fn init(
        self: *@This(),
        memory: vm.Memory,
        buffer_offset: vm.Cell,
        buffer_at_offset: vm.Cell,
        buffer_len_offset: vm.Cell,
    ) Register.Error!void {
        self.memory = memory;
        self.buffer_offset = buffer_offset;
        self.buffer_len.init(self.memory, buffer_len_offset);
        self.buffer_at.init(self.memory, buffer_at_offset);

        try self.buffer_len.store(0);
        try self.buffer_at.store(0);

        self.refill_fn = null;
        self.refill_userdata = null;
    }

    // TODO maybe make this private ?
    pub fn setInputBuffer(self: *@This(), buffer: []const u8) Error!void {
        if (buffer.len > max_buffer_len) {
            return error.OversizeInputBuffer;
        }
        const mem_slice = vm.sliceFromAddrAndLen(
            self.memory,
            self.buffer_offset,
            buffer.len,
        );
        std.mem.copyForwards(u8, mem_slice, buffer);
        try self.buffer_at.store(0);
        try self.buffer_len.store(@truncate(buffer.len));
    }

    pub fn setRefillCallback(
        self: *@This(),
        refill_fn: RefillFn,
        userdata: *anyopaque,
    ) void {
        self.refill_fn = refill_fn;
        self.refill_userdata = userdata;
    }

    pub fn readNextChar(self: *@This()) Error!?u8 {
        const buffer_at = try self.buffer_at.fetch();
        const buffer_len = try self.buffer_len.fetch();
        if (buffer_at < buffer_len) {
            const ret = self.memory[self.buffer_offset + buffer_at];
            try self.buffer_at.storeAdd(1);
            return ret;
        } else {
            return null;
        }
    }

    fn skipWhitespace(self: *@This()) Error!?u8 {
        var char = try self.readNextChar() orelse return null;
        while (isWhitespace(char)) {
            char = (try self.readNextChar()) orelse return null;
        }
        return char;
    }

    pub fn readNextWordRange(self: *@This()) Error!?struct {
        address: vm.Cell,
        len: vm.Cell,
    } {
        var char = try self.skipWhitespace() orelse return null;

        const word_start = try self.buffer_at.fetch() - 1;

        while (true) {
            char = (try self.readNextChar()) orelse break;
            if (isWhitespace(char)) {
                try self.buffer_at.storeSubtract(1);
                break;
            }
        }

        const word_end = try self.buffer_at.fetch();
        return .{
            .address = self.buffer_offset + word_start,
            .len = word_end - word_start,
        };
    }

    pub fn readNextWord(self: *@This()) Error!?[]const u8 {
        const range = try self.readNextWordRange() orelse return null;
        return vm.sliceFromAddrAndLen(self.memory, range.address, range.len);
    }

    pub fn refill(
        self: *@This(),
    ) Error!void {
        const refill_fn = self.refill_fn orelse return error.CannotRefill;
        const userdata = self.refill_userdata orelse return error.CannotRefill;
        const buffer = try refill_fn(userdata);
        try self.setInputBuffer(buffer);
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
    try input_source.init(
        mem,
        buffer_offset,
        at_offset,
        len_offset,
    );
    const refill_str = "refill";
    input_source.setRefillCallback(testRefill, @ptrCast(@constCast(&@as([]const u8, refill_str))));

    try input_source.setInputBuffer("asdf wowo hellow");

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

fn testRefill(userdata: *anyopaque) vm.InputError![]const u8 {
    const str: *[]const u8 = @ptrCast(@alignCast(userdata));
    return str.*;
}
