pub const RefillFn = *const fn (userdata: ?*anyopaque, buffer: []u8) error{CannotRefill}!?usize;

pub const Refiller = struct {
    callback: RefillFn,
    userdata: *anyopaque,

    pub fn refill(self: *@This(), buffer: []u8) !?usize {
        return try self.callback(self.userdata, buffer);
    }
};
