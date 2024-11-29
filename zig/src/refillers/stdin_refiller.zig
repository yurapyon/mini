const std = @import("std");

const Refiller = @import("refiller.zig").Refiller;

pub const StdInRefiller = struct {
    buffer: [128]u8,
    stdin: std.fs.File,
    prompt: ?[]const u8,

    pub fn init(self: *@This()) void {
        self.stdin = std.io.getStdIn();
    }

    fn refill(self_: ?*anyopaque) !?[]const u8 {
        const self: *@This() = @ptrCast(@alignCast(self_));

        if (self.prompt) |prompt| {
            // TODO Don't use debug
            std.debug.print("{s}", .{prompt});
        }

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
            .id = "stdin",
            .callback = refill,
            .userdata = self,
        };
    }
};
