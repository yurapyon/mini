const std = @import("std");
const Allocator = std.mem.Allocator;

const mini = @import("mini");

const kernel = mini.kernel;
const Kernel = kernel.Kernel;

const externals = mini.externals;
const External = externals.External;
const ExternalsList = externals.ExternalsList;

const mem = mini.mem;

const readFile = mini.utils.readFile;

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
});

// ===

pub const OS = struct {
    allocator: Allocator,

    pub fn init(self: *@This(), allocator: Allocator) void {
        self.allocator = allocator;
    }

    // ===

    fn sleep(k: *Kernel, _: ?*anyopaque) External.Error!void {
        try k.data_stack.assertWontUnderflow(1);

        const value: u64 = k.data_stack.popCell();
        std.Thread.sleep(value * 1000000);
    }

    fn sleepS(k: *Kernel, _: ?*anyopaque) External.Error!void {
        try k.data_stack.assertWontUnderflow(1);

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

    fn shell(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const os: *@This() = @ptrCast(@alignCast(userdata));

        try k.data_stack.assertWontUnderflow(2);

        const len = k.data_stack.popCell();
        const addr = k.data_stack.popCell();
        const command = try mem.constSliceFromAddrAndLen(
            k.memory,
            addr,
            len,
        );
        const temp = os.allocator.alloc(u8, len + 1) catch unreachable;
        defer os.allocator.free(temp);
        std.mem.copyForwards(u8, temp, command);
        temp[len] = 0;
        _ = c.system(temp.ptr);
    }

    fn setAcceptFile(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const os: *@This() = @ptrCast(@alignCast(userdata));

        try k.data_stack.assertWontUnderflow(2);

        k.debug_accept_buffer = true;

        const len = k.data_stack.popCell();
        const addr = k.data_stack.popCell();
        const filepath = try mem.constSliceFromAddrAndLen(k.memory, addr, len);
        const file = readFile(
            os.allocator,
            filepath,
        ) catch return error.ExternalPanic;
        defer os.allocator.free(file);
        k.setAcceptBuffer(file) catch return error.ExternalPanic;
    }

    fn getEnv(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const os: *@This() = @ptrCast(@alignCast(userdata));

        try k.data_stack.assertWontUnderflow(4);

        const buf_len = k.data_stack.popCell();
        const buf_addr = k.data_stack.popCell();
        const env_len = k.data_stack.popCell();
        const env_addr = k.data_stack.popCell();

        const env_var = try mem.constSliceFromAddrAndLen(
            k.memory,
            env_addr,
            env_len,
        );

        const value = std.process.getEnvVarOwned(os.allocator, env_var) catch |err| switch (err) {
            error.EnvironmentVariableNotFound => null,
            else => return error.ExternalPanic,
        };

        if (value) |str| {
            defer os.allocator.free(str);

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
        try k.data_stack.assertWontUnderflow(2);

        const buf_len = k.data_stack.popCell();
        const buf_addr = k.data_stack.popCell();

        const buf = try mem.sliceFromAddrAndLen(
            k.memory,
            buf_addr,
            buf_len,
        );

        const str = std.fs.cwd().realpath(".", buf) catch return error.ExternalPanic;

        k.data_stack.pushCell(@truncate(str.len));
    }

    // TODO could move these somewhere else maybe?
    fn zeroEC(k: *Kernel, _: ?*anyopaque) External.Error!void {
        k.debug.exec_counter = 0;
    }

    fn fetchEC(k: *Kernel, _: ?*anyopaque) External.Error!void {
        k.data_stack.pushCell(k.debug.exec_counter);
    }

    fn enableTCO(k: *Kernel, _: ?*anyopaque) External.Error!void {
        k.debug.enable_tco = true;
    }

    fn disableTCO(k: *Kernel, _: ?*anyopaque) External.Error!void {
        k.debug.enable_tco = false;
    }

    pub fn pushExternals(self: *@This(), exts: *ExternalsList) !void {
        try exts.pushSlice(&.{
            .{
                .name = "sleep",
                .callback = sleep,
                .userdata = self,
            },
            .{
                .name = "sleeps",
                .callback = sleepS,
                .userdata = self,
            },
            .{
                .name = "time-utc",
                .callback = time,
                .userdata = self,
            },
            .{
                .name = "shell",
                .callback = shell,
                .userdata = self,
            },
            .{
                .name = "accept-file",
                .callback = setAcceptFile,
                .userdata = self,
            },
            .{
                .name = "get-env",
                .callback = getEnv,
                .userdata = self,
            },
            .{
                .name = "cwd",
                .callback = cwd,
                .userdata = self,
            },
            .{
                .name = "_0ec!",
                .callback = zeroEC,
                .userdata = self,
            },
            .{
                .name = "_ec@",
                .callback = fetchEC,
                .userdata = self,
            },
            .{
                .name = "_tco",
                .callback = enableTCO,
                .userdata = self,
            },
            .{
                .name = "_no-tco",
                .callback = disableTCO,
                .userdata = self,
            },
        });
    }
};
