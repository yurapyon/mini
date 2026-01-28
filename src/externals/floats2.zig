const std = @import("std");
const Allocator = std.mem.Allocator;

const nitori = @import("nitori");
const Pool = nitori.pool.Pool;

const mini = @import("mini");

const kernel = mini.kernel;
const Kernel = kernel.Kernel;
const Cell = kernel.Cell;

const externals = @import("externals.zig");
const External = externals.External;
const ExternalsList = externals.ExternalsList;

const mem = mini.mem;

// ===

const Float = f32;

fn parseFloat(str: []const u8) !Float {
    for (str) |ch| {
        switch (ch) {
            '0'...'9', '.', '+', '-' => {},
            else => {
                return error.InvalidFloat;
            },
        }
    }

    if (str.len == 1 and
        (str[0] == '+' or
            str[0] == '-' or
            str[0] == '.'))
    {
        return error.InvalidFloat;
    }

    const f = std.fmt.parseFloat(Float, str) catch |err| switch (err) {
        error.InvalidCharacter => {
            return error.InvalidFloat;
        },
    };

    return f;
}

// ===

// TODO
// Float pool
// 'floats' are an index on the stack
//  slows down math but makes it so you can reuse all th existing dup/swap/drop words

pub const Floats = struct {
    pool: Pool(Float),

    pub fn init(self: *@This(), allocator: Allocator, size: Cell) !void {
        try self.pool.init(allocator, size);
    }

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        self.pool.deinit(allocator);
    }

    // ===

    fn fPlus(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const f: *@This() = @ptrCast(@alignCast(userdata));

        const a_id = k.data_stack.popCell();
        const b_id = k.data_stack.popCell();

        const a = f.pool.data.items[a_id];
        const b = f.pool.data.items[b_id];
        const c = b + a;

        f.pool.data.items[a_id] = c;
        f.pool.kill(b_id);

        k.data_stack.pushCell(a_id);
    }

    fn fMinus(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const f: *@This() = @ptrCast(@alignCast(userdata));

        const a_id = k.data_stack.popCell();
        const b_id = k.data_stack.popCell();

        const a = f.pool.data.items[a_id];
        const b = f.pool.data.items[b_id];
        const c = b - a;

        f.pool.data.items[a_id] = c;
        f.pool.kill(b_id);

        k.data_stack.pushCell(a_id);
    }

    fn fMultiply(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const f: *@This() = @ptrCast(@alignCast(userdata));

        const a_id = k.data_stack.popCell();
        const b_id = k.data_stack.popCell();

        const a = f.pool.data.items[a_id];
        const b = f.pool.data.items[b_id];
        const c = b * a;

        f.pool.data.items[a_id] = c;
        f.pool.kill(b_id);

        k.data_stack.pushCell(a_id);
    }

    fn fDivide(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const f: *@This() = @ptrCast(@alignCast(userdata));

        const a_id = k.data_stack.popCell();
        const b_id = k.data_stack.popCell();

        const a = f.pool.data.items[a_id];
        const b = f.pool.data.items[b_id];
        const c = b / a;

        // TODO this shouldnt assign, should create new
        f.pool.data.items[a_id] = c;
        f.pool.kill(b_id);

        k.data_stack.pushCell(a_id);
    }

    fn fToString(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const f: *@This() = @ptrCast(@alignCast(userdata));

        const len = k.data_stack.popCell();
        const addr = k.data_stack.popCell();
        const f_id = k.data_stack.popCell();

        const value = f.pool.data.items[f_id];
        f.pool.kill(f_id);

        const buf = try mem.sliceFromAddrAndLen(
            k.memory,
            addr,
            len,
        );

        const out = std.fmt.bufPrint(buf, "{}", .{value}) catch |err| switch (err) {
            error.NoSpaceLeft => &[_]u8{},
        };

        k.data_stack.pushCell(@truncate(out.len));
    }

    fn stringToF(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const f: *@This() = @ptrCast(@alignCast(userdata));

        const len = k.data_stack.popCell();
        const addr = k.data_stack.popCell();

        const str = try mem.constSliceFromAddrAndLen(
            k.memory,
            addr,
            len,
        );

        const value = parseFloat(str) catch {
            k.data_stack.pushCell(0);
            k.data_stack.pushCell(0);
            k.data_stack.pushBoolean(false);
            return;
        };

        const f_id = f.pool.trySpawn() catch unreachable;
        f.pool.data.items[f_id] = value;

        k.data_stack.pushCell(@truncate(f_id));
        k.data_stack.pushBoolean(true);
    }

    pub fn pushExternals(self: *@This(), exts: *ExternalsList) !void {
        try exts.pushSlice(&.{
            .{
                .name = "f+",
                .callback = fPlus,
                .userdata = self,
            },
            .{
                .name = "f-",
                .callback = fMinus,
                .userdata = self,
            },
            .{
                .name = "f*",
                .callback = fMultiply,
                .userdata = self,
            },
            .{
                .name = "f/",
                .callback = fDivide,
                .userdata = self,
            },
            .{
                .name = "f>str",
                .callback = fToString,
                .userdata = self,
            },
            .{
                .name = "str>f",
                .callback = stringToF,
                .userdata = self,
            },
        });
    }

    pub fn getStartupFile(_: *@This()) []const u8 {
        return @embedFile("floats.mini.fth");
    }
};
