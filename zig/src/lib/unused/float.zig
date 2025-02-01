const utils = @import("../utils.zig");
const defaultParseNumber = utils.parseNumber;
const ParseNumberError = utils.ParseNumberError;

const runtime = @import("../runtime.zig");
const Runtime = runtime.Runtime;
const Cell = runtime.Cell;
const ExternalError = runtime.ExternalError;

const externals = @import("../externals.zig");
const External = externals.External;

const Handles = @import("../utils/handles.zig").Handles;

// ===

const ExternalId = enum(Cell) {
    f_plus,
    f_minus,
    f_times,
    f_div,
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

fn parseNumber(str: []const u8, base: usize) ParseNumberError!usize {
    const number_or_error = defaultParseNumber(str, base);
    const maybe_number = number_or_error catch |err| switch (err) {
        error.InvalidNumber => null,
        else => return err,
    };
    if (maybe_number) |value| {
        return value;
    } else {
        // TODO try parse float
        return error.InvalidNumber;
    }
}

pub const Files = struct {
    rt: *Runtime,
    handles: Handles,

    start_token: Cell,

    pub fn init(self: *@This(), rt: *Runtime) !void {
        self.rt = rt;
        self.handles.init(rt.allocator);
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
            @intFromEnum(ExternalId.open) + start_token,
        );
        try self.rt.addExternal(external);

        self.start_token = start_token;
        return @intFromEnum(ExternalId._max) + self.start_token;
    }
};
