const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const CliOptions = struct {
    interactive: bool,
    run_system: bool,
    filepaths: ArrayList([]u8),

    pub fn initFromProcessArgs(self: *@This(), allocator: Allocator) !void {
        var iter = try std.process.argsWithAllocator(allocator);
        defer iter.deinit();

        self.interactive = true;
        self.run_system = false;

        self.filepaths = ArrayList([]u8).init(allocator);
        errdefer self.filepaths.deinit();

        _ = iter.skip();
        while (iter.next()) |arg| {
            if (arg.len >= 2) {
                if (arg[0] == '-') {
                    switch (arg[1]) {
                        'i' => self.interactive = !self.interactive,
                        's' => self.run_system = !self.run_system,
                        else => {},
                    }
                } else {
                    // TODO copy arg
                    // self.filepaths.addOne();
                }
            }
        }
    }

    pub fn deinit(self: @This()) void {
        // TODO free each filepath
        self.filepaths.deinit();
    }
};
