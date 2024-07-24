const vm = @import("MiniVM.zig");

pub fn isWhitespace(char: u8) bool {
    return char == ' ' or char == '\n';
}

// TODO turn this into a device instead
// TODO this should use a buffer in vm memory rather than its own memory

/// Forth-style input:
///   i.e. line-by-line input from a buffer
//         ability to read from stdin if no buffer is supplied (TODO)
pub const InputSource = struct {
    pub const RefillFn = *const fn () []const u8;

    input_buffer: ?[]const u8,
    input_buffer_at: usize,
    refill_fn: ?RefillFn,

    pub fn init(self: *@This()) void {
        self.input_buffer = null;
        self.input_buffer_at = 0;
        self.refill_fn = null;
    }

    pub fn setInputBuffer(self: *@This(), buffer: []const u8) void {
        self.input_buffer = buffer;
        self.input_buffer_at = 0;
    }

    pub fn readNextChar(self: *@This()) vm.InputError!?u8 {
        if (self.input_buffer) |input_buffer| {
            if (self.input_buffer_at < input_buffer.len) {
                const ret = input_buffer[self.input_buffer_at];
                self.input_buffer_at += 1;
                return ret;
            } else {
                return null;
            }
        } else {
            return error.NoInputBuffer;
        }
    }

    fn skipWhitespace(self: *@This()) vm.InputError!?u8 {
        var char = try self.readNextChar() orelse return null;
        while (isWhitespace(char)) {
            char = (try self.readNextChar()) orelse return null;
        }
        return char;
    }

    pub fn readNextWord(self: *@This()) vm.InputError!?[]const u8 {
        if (self.input_buffer) |input_buffer| {
            var char = try self.skipWhitespace() orelse return null;

            const word_start = self.input_buffer_at - 1;

            while (true) {
                char = (try self.readNextChar()) orelse break;
                if (isWhitespace(char)) {
                    self.input_buffer_at -= 1;
                    break;
                }
            }

            const word_end = self.input_buffer_at;

            return input_buffer[word_start..word_end];
        } else {
            return error.NoInputBuffer;
        }
    }

    pub fn refill(
        self: *@This(),
    ) vm.InputError!void {
        if (self.refill_fn) |refill_fn| {
            self.input_buffer = refill_fn();
            self.input_buffer_at = 0;
        } else {
            return error.CannotRefill;
        }
    }
};

test "input-sources" {
    const testing = @import("std").testing;

    var input_source: InputSource = undefined;
    input_source.init();
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

fn testRefill() []const u8 {
    return "refill";
}
