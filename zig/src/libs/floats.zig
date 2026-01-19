const std = @import("std");

const mini = @import("mini");

const kernel = mini.kernel;
const Kernel = kernel.Kernel;

const externals = mini.externals;
const External = externals.External;
const ExternalsList = externals.ExternalsList;

const mem = mini.mem;

// ===

const Float = f32;

// TODO
// it would be hard to reinterpret the stack memory as float*
//   this would require the stack is float aligned, which isn't guaranteed
//   this could be better for performance though
// think about using a separte float stack

fn popFloat(k: *Kernel) Float {
    const hi: u32 = k.data_stack.popCell();
    const lo: u32 = k.data_stack.popCell();
    const f: Float = @bitCast(lo | (hi << 16));
    return f;
}

fn pushFloat(k: *Kernel, f: Float) void {
    const hi: u32 = @as(u32, @bitCast(f)) >> 16;
    const lo: u32 = @bitCast(f);
    k.data_stack.pushCell(@truncate(lo));
    k.data_stack.pushCell(@truncate(hi));
}

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

fn fPlus(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const a = popFloat(k);
    const b = popFloat(k);
    const c = b + a;
    pushFloat(k, c);
}

fn fMinus(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const a = popFloat(k);
    const b = popFloat(k);
    const c = b - a;
    pushFloat(k, c);
}

fn fMultiply(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const a = popFloat(k);
    const b = popFloat(k);
    const c = b * a;
    pushFloat(k, c);
}

fn fDivide(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const a = popFloat(k);
    const b = popFloat(k);
    const c = b / a;
    pushFloat(k, c);
}

fn fToString(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const len = k.data_stack.popCell();
    const addr = k.data_stack.popCell();
    const f = popFloat(k);

    const buf = try mem.sliceFromAddrAndLen(
        k.memory,
        addr,
        len,
    );

    const out = std.fmt.bufPrint(buf, "{}", .{f}) catch |err| switch (err) {
        error.NoSpaceLeft => &[_]u8{},
    };

    k.data_stack.pushCell(@truncate(out.len));
}

fn stringToF(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const len = k.data_stack.popCell();
    const addr = k.data_stack.popCell();

    const str = try mem.constSliceFromAddrAndLen(
        k.memory,
        addr,
        len,
    );

    const f = parseFloat(str) catch {
        k.data_stack.pushCell(0);
        k.data_stack.pushCell(0);
        k.data_stack.pushBoolean(false);
        return;
    };

    pushFloat(k, f);
    k.data_stack.pushBoolean(true);
}

pub fn pushExternals(exts: *ExternalsList) !void {
    try exts.pushSlice(&.{
        .{
            .name = "f+",
            .callback = fPlus,
            .userdata = null,
        },
        .{
            .name = "f-",
            .callback = fMinus,
            .userdata = null,
        },
        .{
            .name = "f*",
            .callback = fMultiply,
            .userdata = null,
        },
        .{
            .name = "f/",
            .callback = fDivide,
            .userdata = null,
        },
        .{
            .name = "f>str",
            .callback = fToString,
            .userdata = null,
        },
        .{
            .name = "str>f",
            .callback = stringToF,
            .userdata = null,
        },
    });
}
