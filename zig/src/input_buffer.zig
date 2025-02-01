const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const mem = @import("memory.zig");
const MemoryPtr = mem.MemoryPtr;

const runtime = @import("runtime.zig");
const Cell = runtime.Cell;
const Runtime = runtime.Runtime;
const MainMemoryLayout = runtime.MainMemoryLayout;

const register = @import("register.zig");
const Register = register.Register;

const Refiller = @import("refiller.zig").Refiller;

// ===

pub fn isWhitespace(char: u8) bool {
    return char == ' ' or char == '\n';
}

// TODO move this into runtime.zig
const input_buffer_len = 128;

pub const InputBuffer = struct {
    const buffer_offset = MainMemoryLayout.offsetOf("input_buffer");

    memory: MemoryPtr,

    ptr: Register(MainMemoryLayout.offsetOf("source_ptr")),
    len: Register(MainMemoryLayout.offsetOf("source_len")),
    at: Register(MainMemoryLayout.offsetOf("source_at")),

    refiller: ?Refiller,

    pub fn init(self: *@This(), memory: MemoryPtr) void {
        self.memory = memory;

        self.ptr.init(memory);
        self.len.init(memory);
        self.at.init(memory);

        self.ptr.store(0);
        self.len.store(0);
        self.at.store(0);

        self.refiller = null;
    }

    pub fn refill(self: *@This()) !bool {
        if (self.refiller) |*refiller| {
            if (self.ptr.fetch() == 0) {
                const slice = try mem.sliceFromAddrAndLen(
                    self.memory,
                    buffer_offset,
                    input_buffer_len,
                );
                const bytes_refilled = try refiller.refill(slice);
                if (bytes_refilled) |byte_ct| {
                    self.len.store(@intCast(byte_ct));
                    self.at.store(0);
                    return true;
                } else {
                    return false;
                }
            } else {
                return false;
            }
        } else {
            return error.CannotRefill;
        }
    }

    // ===

    // returns null on end of input
    pub fn readNextChar(self: *@This()) ?u8 {
        // TODO
        // this logic is messy and maybe can be consolidated
        const source_ptr = self.ptr.fetch();
        const source_len = self.len.fetch();
        const source_at = self.at.fetch();
        if (source_ptr == 0) {
            // NOTE
            // self.len can be changed from forth, and thus can be invalid
            //   even if reading from the input buffer
            // instead of returning an error we just wrap it
            if (source_at < source_len % input_buffer_len) {
                // NOTE
                // this access will be inbounds as long as
                //   buffer_offset + input_buffer_len is in bounds
                const ret = self.memory[buffer_offset + source_at];
                self.at.storeAdd(1);
                return ret;
            } else {
                return null;
            }
        } else {
            if (source_at < source_len) {
                // TODO dont catch unreachable
                const slice = mem.constSliceFromAddrAndLen(
                    self.memory,
                    source_ptr,
                    source_len,
                ) catch unreachable;
                const ret = slice[source_at];
                self.at.storeAdd(1);
                return ret;
            } else {
                return null;
            }
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

        const source_ptr = self.ptr.fetch();

        const buffer_addr = if (source_ptr == 0) buffer_offset else source_ptr;

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
            .address = buffer_addr + word_start,
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
