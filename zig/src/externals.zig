const kernel = @import("kernel.zig");
const Kernel = kernel.Kernel;
const Cell = kernel.Cell;

const bytecodes = @import("bytecodes.zig");

pub const External = struct {
    pub const Error = error{
        ExternalPanic,
    } || bytecodes.Error;

    pub const Callback = *const fn (
        k: *Kernel,
        userdata: ?*anyopaque,
    ) Error!void;

    name: []const u8,
    callback: Callback,
    userdata: ?*anyopaque,

    pub fn call(self: *@This(), k: *Kernel) !void {
        try self.callback(k, self.userdata);
    }
};
