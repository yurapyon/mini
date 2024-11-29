const std = @import("std");
const GenericReader = std.io.GenericReader;

const Refiller = @import("refiller.zig").Refiller;

pub fn ReaderRefiller() type {
    return struct {
        buffer: [128]u8,
        reader: GenericReader,

        pub fn init(self: *@This(), reader: GenericReader) void {
            self.reader = reader;
        }

        pub fn refill(self_: ?*anyopaque) error{CannotRefill}!?[]const u8 {
            const self: *@This() = @ptrCast(@alignCast(self_));
            const slice = self.reader.readUntilDelimiterOrEof(
                self.buffer[0..self.buffer.len],
                '\n',
            ) catch return error.CannotRefill;
            if (slice) |slc| {
                return self.buffer[0..slc.len];
            } else {
                return null;
            }
        }

        pub fn toRefiller(self: *@This()) Refiller {
            return .{
                .callback = refill,
                .userdata = self,
            };
        }
    };
}
