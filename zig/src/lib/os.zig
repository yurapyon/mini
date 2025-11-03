const std = @import("std");

const kernel = @import("../kernel.zig");
const Kernel = kernel.Kernel;

const externals = @import("../externals.zig");
const External = externals.External;

const mem = @import("../memory.zig");

const readFile = @import("../utils/read-file.zig").readFile;

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
});

// ===

fn sleep(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const value: u64 = k.data_stack.popCell();
    std.Thread.sleep(value * 1000000);
}

fn sleepS(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const value: u64 = k.data_stack.popCell();
    std.Thread.sleep(value * 1000000000);
}

fn time(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const timestamp = std.time.timestamp();
    const seconds = @rem(timestamp, 60);
    const minutes = @rem(@divFloor(timestamp, 60), 60);
    const hours = @rem(@divFloor(timestamp, 3600), 24);
    k.data_stack.pushCell(@intCast(hours));
    k.data_stack.pushCell(@intCast(minutes));
    k.data_stack.pushCell(@intCast(seconds));
}

fn shell(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const len = k.data_stack.popCell();
    const addr = k.data_stack.popCell();
    const command = try mem.constSliceFromAddrAndLen(
        k.memory,
        addr,
        len,
    );
    const temp = k.allocator.alloc(u8, len + 1) catch unreachable;
    defer k.allocator.free(temp);
    std.mem.copyForwards(u8, temp, command);
    temp[len] = 0;
    _ = c.system(temp.ptr);
}

fn setAcceptFile(k: *Kernel, _: ?*anyopaque) External.Error!void {
    k.debug_accept_buffer = true;

    const len = k.data_stack.popCell();
    const addr = k.data_stack.popCell();
    const filepath = try mem.constSliceFromAddrAndLen(k.memory, addr, len);
    const file = readFile(
        k.allocator,
        filepath,
    ) catch return error.ExternalPanic;
    defer k.allocator.free(file);
    k.setAcceptBuffer(file) catch return error.ExternalPanic;
}

fn getEnv(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const buf_len = k.data_stack.popCell();
    const buf_addr = k.data_stack.popCell();
    const env_len = k.data_stack.popCell();
    const env_addr = k.data_stack.popCell();

    const env_var = try mem.constSliceFromAddrAndLen(
        k.memory,
        env_addr,
        env_len,
    );

    const value = std.process.getEnvVarOwned(k.allocator, env_var) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => null,
        else => return error.Panic,
    };

    if (value) |str| {
        defer k.allocator.free(str);

        const buf = try mem.sliceFromAddrAndLen(
            k.memory,
            buf_addr,
            buf_len,
        );

        // TODO think about how to handle this error
        if (str.len <= buf.len) {
            @memcpy(buf[0..str.len], str);
            k.data_stack.pushCell(@truncate(str.len));
        } else {
            k.data_stack.pushSignedCell(-1);
        }
    } else {
        k.data_stack.pushCell(0);
    }
}

fn cwd(k: *Kernel, _: ?*anyopaque) External.Error!void {
    const buf_len = k.data_stack.popCell();
    const buf_addr = k.data_stack.popCell();

    const buf = try mem.sliceFromAddrAndLen(
        k.memory,
        buf_addr,
        buf_len,
    );

    const str = std.fs.cwd().realpath(".", buf) catch return error.Panic;

    k.data_stack.pushCell(@truncate(str.len));
}

pub fn registerExternals(k: *Kernel) !void {
    try k.addExternal("sleep", .{
        .callback = sleep,
        .userdata = null,
    });
    try k.addExternal("sleeps", .{
        .callback = sleepS,
        .userdata = null,
    });
    try k.addExternal("time-utc", .{
        .callback = time,
        .userdata = null,
    });
    try k.addExternal("shell", .{
        .callback = shell,
        .userdata = null,
    });
    try k.addExternal("accept-file", .{
        .callback = setAcceptFile,
        .userdata = null,
    });
    try k.addExternal("get-env", .{
        .callback = getEnv,
        .userdata = null,
    });
    try k.addExternal("cwd", .{
        .callback = cwd,
        .userdata = null,
    });
}
