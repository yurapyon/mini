const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const CliOptions = struct {
    allocator: Allocator,
    interactive: bool,
    run_system: bool,
    precompile: bool,
    filepaths: ArrayList([]u8),
    image_filepath: ?[]u8,
    kernel_filepath: ?[]u8,

    pub fn initFromProcessArgs(self: *@This(), allocator: Allocator) !void {
        self.allocator = allocator;

        var iter = try std.process.argsWithAllocator(self.allocator);
        defer iter.deinit();

        self.interactive = true;
        self.run_system = false;
        self.precompile = false;

        self.filepaths = ArrayList([]u8).init(self.allocator);
        errdefer self.filepaths.deinit();

        var expect_image_filepath = false;
        self.image_filepath = null;

        var expect_kernel_filepath = false;
        self.kernel_filepath = null;

        _ = iter.skip();
        while (iter.next()) |arg| {
            // just ignore it
            if (arg.len < 1) continue;

            if (expect_image_filepath and self.image_filepath == null) {
                expect_image_filepath = false;
                // TODO errdefer
                const filepath = try self.allocator.alloc(u8, arg.len);
                @memcpy(filepath, arg);
                self.image_filepath = filepath;
                continue;
            }

            if (expect_kernel_filepath and self.kernel_filepath == null) {
                expect_kernel_filepath = false;
                // TODO errdefer
                const filepath = try self.allocator.alloc(u8, arg.len);
                @memcpy(filepath, arg);
                self.kernel_filepath = filepath;
                continue;
            }

            if (arg[0] == '-') {
                switch (arg[1]) {
                    'i' => self.interactive = !self.interactive,
                    's' => self.run_system = !self.run_system,
                    'I' => expect_image_filepath = true,
                    'k' => expect_kernel_filepath = true,
                    'p' => self.precompile = !self.precompile,
                    else => {},
                }
            } else {
                // assume its a filepath
                // TODO errdefer
                const filepath = try self.allocator.alloc(u8, arg.len);
                @memcpy(filepath, arg);
                try self.filepaths.append(filepath);
            }
        }
    }

    pub fn deinit(self: @This()) void {
        if (self.image_filepath) |image_filepath| {
            self.allocator.free(image_filepath);
        }
        var i: usize = 0;
        while (i < self.filepaths.items.len) : (i += 1) {
            self.allocator.free(self.filepaths.items[i]);
        }
        self.filepaths.deinit();
    }
};
