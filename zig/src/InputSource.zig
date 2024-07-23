const vm = @import("MiniVM.zig");

pub fn isWhitespace(char: u8) bool {
    return char == ' ' or char == '\n';
}

// TODO turn this into a device instead
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
            if (self.input_buffer_at + 1 < input_buffer.len) {
                self.input_buffer_at += 1;
                return input_buffer[self.input_buffer_at];
            } else {
                return null;
            }
        } else {
            return error.NoInputBuffer;
        }
    }

    pub fn readNextWord(self: *@This()) vm.InputError!?[]const u8 {
        if (self.input_buffer) |input_buffer| {
            var char = input_buffer[self.input_buffer_at];

            while (isWhitespace(char)) {
                char = (try self.readNextChar()) orelse return null;
            }

            const word_start = self.input_buffer_at;

            while (!isWhitespace(char)) {
                char = (try self.readNextChar()) orelse break;
            }

            return input_buffer[word_start..self.input_buffer_at];
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

test "input sources" {
    // TODO
    // readNextChar
    // readNextWord
}
