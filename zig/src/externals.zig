const kernel = @import("kernel.zig");
const Kernel = kernel.Kernel;
const Cell = kernel.Cell;

const bytecodes = @import("kernel_bytecodes.zig");

pub const External = struct {
    pub const Error = error{
        ExternalPanic,
    } || bytecodes.Error;

    pub const Callback = *const fn (
        k: *Kernel,
        id: Cell,
        userdata: ?*anyopaque,
    ) Error!bool;

    callback: Callback,
    userdata: ?*anyopaque,

    pub fn call(self: *@This(), k: *Kernel, id: Cell) !bool {
        return self.callback(k, id, self.userdata);
    }
};
