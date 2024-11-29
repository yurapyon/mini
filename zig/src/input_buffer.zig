const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const mem = @import("memory.zig");
const MemoryPtr = mem.MemoryPtr;

const runtime = @import("runtime.zig");
const Cell = runtime.Cell;
const MainMemoryLayout = runtime.MainMemoryLayout;

const register = @import("register.zig");
const Register = register.Register;

const Refiller = @import("refillers/refiller.zig").Refiller;

// ===

pub fn isWhitespace(char: u8) bool {
    return char == ' ' or char == '\n';
}

const input_buffer_len = 128;

pub const InputBuffer = struct {
    const buffer_offset = MainMemoryLayout.offsetOf("input_buffer");

    memory: MemoryPtr,

    at: Register(MainMemoryLayout.offsetOf("input_buffer_at")),
    len: Register(MainMemoryLayout.offsetOf("input_buffer_len")),

    refiller_stack: ArrayList(Refiller),

    pub fn init(self: *@This(), allocator: Allocator, memory: MemoryPtr) void {
        self.memory = memory;
        self.at.init(memory);
        self.len.init(memory);

        self.at.store(0);
        self.len.store(0);

        self.refiller_stack = ArrayList(Refiller).init(allocator);
    }

    fn setInputBuffer(
        self: *@This(),
        buffer: []const u8,
    ) !void {
        if (buffer.len > input_buffer_len) {
            return error.OversizeInputBuffer;
        }
        // NOTE
        // this will always be in-bounds as long as buffer_offset + input_buffer_len is
        const mem_slice = mem.sliceFromAddrAndLen(
            self.memory,
            buffer_offset,
            @intCast(buffer.len),
        ) catch unreachable;
        @memcpy(mem_slice, buffer);
        self.at.store(0);
        self.len.store(@intCast(buffer.len));
    }

    pub fn pushRefiller(
        self: *@This(),
        refiller: Refiller,
    ) !void {
        try self.refiller_stack.append(refiller);
    }

    // Returns whether there are still refillers
    pub fn popRefiller(
        self: *@This(),
    ) bool {
        _ = self.refiller_stack.pop();
        return self.refiller_stack.items.len > 0;
    }

    pub fn refill(self: *@This(), continue_on_empty: bool) !bool {
        while (true) {
            const refiller = &self.refiller_stack
                .items[self.refiller_stack.items.len - 1];
            const buffer = try refiller.refill();
            if (buffer) |buf| {
                try self.setInputBuffer(buf);
                return true;
            } else {
                if (continue_on_empty and self.refiller_stack.items.len > 0) {
                    _ = self.popRefiller();
                } else {
                    return false;
                }
            }
        }
    }

    // ===

    // returns null on end of input
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

    // returns null on end of input
    fn skipWhitespace(self: *@This()) ?u8 {
        var char = self.readNextChar() orelse return null;
        while (isWhitespace(char)) {
            char = self.readNextChar() orelse return null;
        }
        return char;
    }

    // returns null on end of input
    pub fn readNextWordRange(self: *@This()) ?struct {
        address: Cell,
        len: Cell,
    } {
        var char = self.skipWhitespace() orelse return null;

        // NOTE
        // self.at.fetch() is >=1 because we didnt return early after skipWhitespace
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

    // returns null on end of input
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

    var input_buffer: InputBuffer = undefined;
    input_buffer.init(memory);

    const refill_str = "refill";
    input_buffer.setRefillCallback(
        testRefill,
        @ptrCast(@constCast(&@as([]const u8, refill_str))),
    );

    try input_buffer.setInputBuffer("asdf wowo hellow");

    try testing.expectEqual('a', input_buffer.readNextChar());
    try testing.expectEqual('s', input_buffer.readNextChar());
    try testing.expectEqual('d', input_buffer.readNextChar());
    try testing.expectEqual('f', input_buffer.readNextChar());

    try testing.expectEqualSlices(
        u8,
        "wowo",
        input_buffer.readNextWord() orelse return error.OutOfInput,
    );

    _ = try input_buffer.refill();

    try testing.expectEqualSlices(
        u8,
        "refill",
        input_buffer.readNextWord() orelse return error.OutOfInput,
    );
}

fn testRefill(userdata: ?*anyopaque) !?[]const u8 {
    if (userdata) |data| {
        const str: *[]const u8 = @ptrCast(@alignCast(data));
        return str.*;
    } else {
        return "asdf";
    }
}
