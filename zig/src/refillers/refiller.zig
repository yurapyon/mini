pub const RefillFn = *const fn (userdata: ?*anyopaque) error{CannotRefill}!?[]const u8;

pub const Refiller = struct {
    callback: RefillFn,
    userdata: *anyopaque,

    pub fn refill(self: *@This()) !?[]const u8 {
        return try self.callback(self.userdata);
    }
};
