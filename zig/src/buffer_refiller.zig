const std = @import("std");

const Refiller = @import("refiller.zig").Refiller;

pub const BufferRefiller = struct {
    buffer: [128]u8,
    stream: std.io.FixedBufferStream([]const u8),

    pub fn init(self: *@This(), buffer: []const u8) void {
        self.stream = std.io.fixedBufferStream(buffer);
    }

    fn refill(self_: ?*anyopaque) !?[]const u8 {
        const self: *@This() = @ptrCast(@alignCast(self_));
        const slice = self.stream.reader().readUntilDelimiterOrEof(
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
            .id = "buffer",
            .callback = refill,
            .userdata = self,
        };
    }
};
