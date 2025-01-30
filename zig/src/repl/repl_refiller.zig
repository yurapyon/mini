const std = @import("std");

const runtime = @import("../runtime.zig");
const Cell = runtime.Cell;
const Runtime = runtime.Runtime;

const mem = @import("../memory.zig");

const Refiller = @import("../refiller.zig").Refiller;

pub const ReplRefiller = struct {
    buffer: [128]u8,
    stdin: std.fs.File,
    source_addr: Cell,
    source_line: Cell,

    pub fn init(self: *@This()) void {
        self.stdin = std.io.getStdIn();
        self.source_addr = 0;
        self.source_line = 0;
    }

    fn refill(self_: ?*anyopaque, rt: *Runtime) !?[]const u8 {
        const self: *@This() = @ptrCast(@alignCast(self_));

        if (self.source_addr == 0) {
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
        } else {
            const block = mem.constSliceFromAddrAndLen(
                rt.memory,
                self.source_addr,
                1024,
            ) catch return error.CannotRefill;
            const line = block[self.source_line..(self.source_line + 64)];
            return line;
        }
    }

    pub fn toRefiller(self: *@This()) Refiller {
        return .{
            // TODO pretty sure this isnt needed
            .id = "stdin",
            .callback = refill,
            .userdata = self,
        };
    }
};
