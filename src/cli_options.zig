const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const CliOptions = struct {
    interactive: bool,
    run_system: bool,
    precompile: bool,
    filepaths: ArrayList([]u8),
    kernel_filepath: ?[]u8,

    pub fn initFromProcessArgs(self: *@This(), allocator: Allocator) !void {
        var iter = try std.process.argsWithAllocator(allocator);
        defer iter.deinit();

        self.interactive = false;
        self.run_system = false;
        self.precompile = false;

        self.filepaths = .empty;
        errdefer self.filepaths.deinit(allocator);

        var expect_kernel_filepath = false;
        self.kernel_filepath = null;

        _ = iter.skip();
        while (iter.next()) |arg| {
            // just ignore it
            if (arg.len < 1) continue;

            if (expect_kernel_filepath and self.kernel_filepath == null) {
                expect_kernel_filepath = false;
                const filepath = try allocator.alloc(u8, arg.len);
                errdefer allocator.free(filepath);

                @memcpy(filepath, arg);
                self.kernel_filepath = filepath;
                continue;
            }

            if (arg[0] == '-') {
                switch (arg[1]) {
                    'i' => self.interactive = !self.interactive,
                    's' => self.run_system = !self.run_system,
                    'k' => expect_kernel_filepath = true,
                    'p' => self.precompile = !self.precompile,
                    else => {},
                }
            } else {
                // assume its a filepath
                const filepath = try allocator.alloc(u8, arg.len);
                errdefer allocator.free(filepath);

                @memcpy(filepath, arg);
                try self.filepaths.append(allocator, filepath);
            }
        }
    }

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        var i: usize = 0;
        while (i < self.filepaths.items.len) : (i += 1) {
            allocator.free(self.filepaths.items[i]);
        }
        self.filepaths.deinit(allocator);

        if (self.kernel_filepath) |kfp| {
            allocator.free(kfp);
        }
    }
};
