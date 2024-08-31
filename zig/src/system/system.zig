const c = @import("c.zig");

pub const System = struct {
    pub fn init(self: *@This()) !void {
        _ = self;
    }

    pub fn deinit(self: @This()) void {
        _ = self;
    }

    // ===

    pub fn start(self: @This()) !void {
        // setup

        try self.loop();
    }

    pub fn stop(self: @This()) !void {
        _ = self;
    }

    fn loop(self: *@This()) !void {
        _ = self;
    }
};
