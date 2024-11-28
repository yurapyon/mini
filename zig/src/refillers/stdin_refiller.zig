const std = @import("std");

const Refiller = @import("refiller.zig").Refiller;

pub const StdInReader = struct {
    buffer: [128]u8,
    stdin: std.File,

    fn init(self: *@This()) void {
        self.stdin = std.io.getStdIn();
    }

    fn refill(self_: ?*anyopaque) !?[]const u8 {
        const self: *@This() = @ptrCast(@alignCast(self_));
        const slice = self.stdin.reader().readUntilDelimiterOrEof(
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
