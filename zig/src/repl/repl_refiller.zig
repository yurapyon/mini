const std = @import("std");

const runtime = @import("../runtime.zig");
const Cell = runtime.Cell;

const Refiller = @import("../refiller.zig").Refiller;

pub const ReplRefiller = struct {
    buffer: [128]u8,
    stdin: std.fs.File,
    reading_user_input: bool,
    // source: ?[]const u8,
    // source_at: Cell,

    pub fn init(self: *@This()) void {
        self.stdin = std.io.getStdIn();
        self.reading_user_input = true;
    }

    fn refill(self_: ?*anyopaque) !?[]const u8 {
        const self: *@This() = @ptrCast(@alignCast(self_));

        const reader = self.stdin.reader();
        const slice =
            reader.readUntilDelimiterOrEof(
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
