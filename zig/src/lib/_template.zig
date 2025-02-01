const runtime = @import("../runtime.zig");
const Runtime = runtime.Runtime;
const Cell = runtime.Cell;
const ExternalError = runtime.ExternalError;

const externals = @import("../externals.zig");
const External = externals.External;

// ===

const ExternalId = enum(Cell) {
    _max,
    _,
};

fn externalsCallback(rt: *Runtime, token: Cell, userdata: ?*anyopaque) External.Error!bool {
    _ = rt;

    const files = @as(*Files, @ptrCast(@alignCast(userdata)));
    const external_id = @as(ExternalId, @enumFromInt(token - files.start_token));
    _ = external_id;

    return false;
}

pub const Files = struct {
    rt: *Runtime,
    start_token: Cell,

    pub fn init(self: *@This(), rt: *Runtime) !void {
        self.rt = rt;
    }

    pub fn registerExternals(self: *@This(), start_token: Cell) !Cell {
        const external = External{
            .callback = externalsCallback,
            .userdata = self,
        };
        const wlidx = runtime.CompileState.interpret.toWordlistIndex() catch unreachable;
        try self.rt.defineExternal(
            "fopen",
            wlidx,
            @intFromEnum(ExternalId._max) + start_token,
        );
        try self.rt.addExternal(external);

        self.start_token = start_token;
        return @intFromEnum(ExternalId._max) + self.start_token;
    }
};
