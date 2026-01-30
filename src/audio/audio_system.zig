const std = @import("std");
const Allocator = std.mem.Allocator;

const c = @import("./c.zig").c;

const nitori = @import("nitori");
const Channel = nitori.channel.Channel;

const externals = @import("libs").externals;
const External = externals.External;
const ExternalsList = externals.ExternalsList;

const mini = @import("mini");
const kernel = mini.kernel;
const Kernel = kernel.Kernel;
const Cell = kernel.Cell;

// ===

const AudioMessage = union(enum) {
    opl: struct {
        address: u8,
        value: u8,
    },
};

const opl_clock_rate = 3579545;
const sample_rate = 44100;
const input_channels = 0;
const output_channels = 2;

pub const AudioSystem = struct {
    channel: Channel(AudioMessage),
    opl: *c.OPL,

    pub fn init(self: *@This(), allocator: Allocator) !void {
        try self.channel.init(allocator, 128);

        const opl = c.OPL_new(
            opl_clock_rate,
            sample_rate,
        );

        if (opl == null) {
            return error.Memory;
        }
        errdefer c.OPL_delete(opl);

        self.opl = opl;

        c.OPL_setChipType(opl, 2);
        // _ = c.OPL_setMask(opl, 0xffffffff);

        // opl.slot[0].type = 0;

        // c.OPL_writeReg(opl, 0x20, 0x20);
        // c.OPL_writeReg(opl, 0x40, 0x00);
        // c.OPL_writeReg(opl, 0x60, 0xf0);
        // c.OPL_writeReg(opl, 0x80, 0xf7);
        // c.OPL_writeReg(opl, 0xc0, 0x01);

        // c.OPL_writeReg(opl, 0xa0, 0x40);
        // c.OPL_writeReg(opl, 0xb0, 0x2f);

        var err = c.Pa_Initialize();
        if (err != c.paNoError) {
            // TODO error text
            // printf(  "PortAudio error: %s\n", Pa_GetErrorText( err ) );
            return error.PortAudioInit;
        }

        var stream: *c.PaStream = undefined;

        err = c.Pa_OpenDefaultStream(
            @ptrCast(&stream),
            input_channels,
            output_channels,
            c.paFloat32,
            sample_rate,
            c.paFramesPerBufferUnspecified,
            callback,
            self,
        );

        if (err != c.paNoError) {
            return error.InitStream;
        }

        err = c.Pa_StartStream(stream);

        if (err != c.paNoError) {
            return error.InitStream;
        }
    }

    pub fn deinit(self: *@This()) void {
        const err = c.Pa_Terminate();
        if (err != c.paNoError) {
            // TODO
            // return error.PortAudioDeinit;
            unreachable;
        }

        c.OPL_delete(self.opl);

        self.channel.deinit();
    }

    fn callback(
        input_buffer: ?*const anyopaque,
        output_buffer: ?*anyopaque,
        frames_per_buffer: c_ulong,
        time_info: [*c]const c.PaStreamCallbackTimeInfo,
        status_flags: c.PaStreamCallbackFlags,
        userdata: ?*anyopaque,
    ) callconv(.c) c_int {
        const self: *@This() = @ptrCast(@alignCast(userdata));

        while (self.channel.pop() catch null) |msg| {
            switch (msg) {
                .opl => |opl| c.OPL_writeReg(self.opl, opl.address, opl.value),
            }
        }

        _ = input_buffer;
        _ = status_flags;
        _ = time_info;

        const out: [*]f32 = @ptrCast(@alignCast(output_buffer));

        for (0..frames_per_buffer) |i| {
            const opl_out = c.OPL_calc(self.opl);

            const f32_opl: f32 = @floatFromInt(opl_out);
            // const f32_max: f32 = @floatFromInt(std.math.maxInt(i16));

            // std.debug.print("{} {}\n", .{
            // f32_opl,
            // f32_opl / 2048,
            // });

            out[i * 2 + 0] = f32_opl / 2048;
            out[i * 2 + 1] = f32_opl / 2048;
        }

        return 0;
    }

    pub fn pushExternals(self: *@This(), es: *ExternalsList) !void {
        try es.pushSlice(&.{
            .{
                .name = "opl",
                .callback = forthOpl,
                .userdata = self,
            },
        });
    }

    fn forthOpl(k: *Kernel, userdata: ?*anyopaque) External.Error!void {
        const self: *@This() = @ptrCast(@alignCast(userdata));

        const value = k.data_stack.popCell();
        const address = k.data_stack.popCell();

        self.channel.push(.{
            .opl = .{
                .address = @truncate(address),
                .value = @truncate(value),
            },
        }) catch return error.Panic;
    }

    pub fn getStartupFile(_: *@This()) []const u8 {
        return @embedFile("audio.mini.fth");
    }
};
