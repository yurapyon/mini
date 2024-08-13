const mem = @import("memory.zig");
const MemoryPtr = mem.MemoryPtr;

const runtime = @import("runtime.zig");
const Cell = runtime.Cell;
const MainMemoryLayout = runtime.MainMemoryLayout;

const register = @import("register.zig");
const Register = register.Register;

pub const Error = error{
    UnexpectedEndOfInput,
    OversizeInputBuffer,
    CannotRefill,
};

pub fn isWhitespace(char: u8) bool {
    return char == ' ' or char == '\n';
}

pub const RefillFn = *const fn (userdata: ?*anyopaque) Error!?[]const u8;

const input_buffer_len = 128;

pub const InputBuffer = struct {
    const buffer_offset = MainMemoryLayout.offsetOf("input_buffer");

    memory: MemoryPtr,

    at: Register(MainMemoryLayout.offsetOf("input_buffer_at")),
    len: Register(MainMemoryLayout.offsetOf("input_buffer_len")),

    refill_callback: ?RefillFn,
    refill_userdata: ?*anyopaque,

    pub fn init(self: *@This(), memory: MemoryPtr) void {
        self.memory = memory;
        self.at.init(memory);
        self.len.init(memory);

        self.at.store(0);
        self.len.store(0);

        self.refill_callback = null;
        self.refill_userdata = null;
    }

    fn setInputBuffer(
        self: *@This(),
        buffer: []const u8,
    ) (Error || mem.Error)!void {
        if (buffer.len > input_buffer_len) {
            return error.OversizeInputBuffer;
        }
        const mem_slice = try mem.sliceFromAddrAndLen(
            self.memory,
            buffer_offset,
            @intCast(buffer.len),
        );
        @memcpy(mem_slice, buffer);
        self.at.store(0);
        self.len.store(@intCast(buffer.len));
    }

    pub fn setRefillCallback(
        self: *@This(),
        refill_callback: RefillFn,
        userdata: ?*anyopaque,
    ) void {
        self.refill_callback = refill_callback;
        self.refill_userdata = userdata;
    }

    pub fn refill(self: *@This()) (Error || mem.Error)!bool {
        const refill_callback = self.refill_callback orelse return error.CannotRefill;
        const buffer = try refill_callback(self.refill_userdata);
        if (buffer) |buf| {
            try self.setInputBuffer(buf);
            return true;
        } else {
            return false;
        }
    }

    // ===

    // NOTE
    // this doesnt try to refill
    pub fn readNextChar(self: *@This()) ?u8 {
        const buffer_at = self.at.fetch();
        // NOTE
        // self.len is checked in setInputBuffer when the buffer is updated from zig
        // however, self.len can be changed from forth, and thus can be invalid
        //   i.e. greater than input_buffer_len
        // instead of returning an error we just wrap it
        const buffer_len = self.len.fetch() % input_buffer_len;

        if (buffer_at < buffer_len) {
            // NOTE
            // this access will be inbounds as long as
            //   buffer_offset + input_buffer_len is in bounds
            const ret = self.memory[buffer_offset + buffer_at];
            self.at.storeAdd(1);
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
        address: Cell,
        len: Cell,
    } {
        var char = self.skipWhitespace() orelse return null;

        // NOTE
        // self.at.fetch() is >1 because we didnt return early after skipWhitespace
        const word_start = self.at.fetch() - 1;

        while (true) {
            char = self.readNextChar() orelse break;
            if (isWhitespace(char)) {
                self.at.storeSubtract(1);
                break;
            }
        }

        const word_end = self.at.fetch();
        return .{
            .address = buffer_offset + word_start,
            .len = word_end - word_start,
        };
    }

    pub fn readNextWord(self: *@This()) ?[]const u8 {
        const range = self.readNextWordRange() orelse return null;
        return mem.sliceFromAddrAndLen(
            self.memory,
            range.address,
            range.len,
        ) catch unreachable;
    }
};

test "input buffer" {
    const testing = @import("std").testing;

    const memory = try mem.allocateMemory(testing.allocator);
    defer testing.allocator.free(memory);

    var input_source: InputBuffer = undefined;
    input_source.init(memory);

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

fn testRefill(userdata: ?*anyopaque) Error!?[]const u8 {
    if (userdata) |data| {
        const str: *[]const u8 = @ptrCast(@alignCast(data));
        return str.*;
    } else {
        return "asdf";
    }
}
