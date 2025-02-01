const runtime = @import("runtime.zig");
const Runtime = runtime.Runtime;
const Cell = runtime.Cell;

const bytecodes = @import("bytecodes.zig");

pub const External = struct {
    pub const Error = error{
        ExternalPanic,
    } || bytecodes.Error;

    pub const Callback = *const fn (
        rt: *Runtime,
        id: Cell,
        userdata: ?*anyopaque,
    ) Error!bool;

    callback: Callback,
    userdata: ?*anyopaque,

    pub fn call(self: *@This(), rt: *Runtime, id: Cell) !bool {
        return self.callback(rt, id, self.userdata);
    }
};
