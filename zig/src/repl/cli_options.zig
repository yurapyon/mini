const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const CliOptions = struct {
    allocator: Allocator,
    interactive: bool,
    run_system: bool,
    filepaths: ArrayList([]u8),

    pub fn initFromProcessArgs(self: *@This(), allocator: Allocator) !void {
        self.allocator = allocator;

        var iter = try std.process.argsWithAllocator(self.allocator);
        defer iter.deinit();

        self.interactive = true;
        self.run_system = false;

        self.filepaths = ArrayList([]u8).init(self.allocator);
        errdefer self.filepaths.deinit();

        _ = iter.skip();
        while (iter.next()) |arg| {
            // just ignore it
            if (arg.len < 1) continue;

            if (arg[0] == '-') {
                switch (arg[1]) {
                    'i' => self.interactive = !self.interactive,
                    's' => self.run_system = !self.run_system,
                    else => {},
                }
            } else {
                // assume its a filepath
                const filepath = try self.allocator.alloc(u8, arg.len);
                @memcpy(filepath, arg);
                try self.filepaths.append(filepath);
            }
        }
    }

    pub fn deinit(self: @This()) void {
        var i: usize = 0;
        while (i < self.filepaths.items.len) : (i += 1) {
            self.allocator.free(self.filepaths.items[i]);
        }
        self.filepaths.deinit();
    }
};
