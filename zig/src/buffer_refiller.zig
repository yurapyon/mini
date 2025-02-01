const std = @import("std");

const runtime = @import("runtime.zig");
const Runtime = runtime.Runtime;

const Refiller = @import("refiller.zig").Refiller;

pub const BufferRefiller = struct {
    stream: std.io.FixedBufferStream([]const u8),

    pub fn init(self: *@This(), buffer: []const u8) void {
        self.stream = std.io.fixedBufferStream(buffer);
    }

    fn refill(self_: ?*anyopaque, out: []u8) !?usize {
        const self: *@This() = @ptrCast(@alignCast(self_));
        const slice = self.stream.reader().readUntilDelimiterOrEof(
            out[0..out.len],
            '\n',
        ) catch return error.CannotRefill;
        if (slice) |slc| {
            return slc.len;
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
