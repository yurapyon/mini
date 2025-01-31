const runtime = @import("runtime.zig");
const Runtime = runtime.Runtime;

pub const RefillFn = *const fn (userdata: ?*anyopaque, rt: *Runtime) error{CannotRefill}!?[]const u8;

pub const Refiller = struct {
    callback: RefillFn,
    userdata: *anyopaque,

    pub fn refill(self: *@This(), rt: *Runtime) !?[]const u8 {
        return try self.callback(self.userdata, rt);
    }
};
