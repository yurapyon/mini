const c = @import("./c.zig").c;

// ===

const SawGenerator = struct {
    left_phase: f32,
    right_phase: f32,

    fn init(self: *@This()) void {
        self.left_phase = 0;
        self.right_phase = 0;
    }

    fn callback(
        input_buffer: ?*const anyopaque,
        output_buffer: ?*anyopaque,
        frames_per_buffer: c_ulong,
        time_info: [*c]const c.PaStreamCallbackTimeInfo,
        status_flags: c.PaStreamCallbackFlags,
        userdata: ?*anyopaque,
    ) callconv(.c) c_int {
        _ = input_buffer;
        _ = status_flags;
        _ = time_info;

        const self: *@This() = @ptrCast(@alignCast(userdata));
        const out: [*]f32 = @ptrCast(@alignCast(output_buffer));

        for (0..frames_per_buffer) |i| {
            out[i * 2] = self.left_phase / 4;
            out[i * 2 + 1] = self.right_phase / 4;

            self.left_phase += 0.01;
            self.right_phase += 0.03;

            if (self.left_phase >= 1.0) {
                self.left_phase -= 2.0;
            }

            if (self.right_phase >= 1.0) {
                self.right_phase -= 2.0;
            }
        }

        return 0;
    }
};

const sample_rate = 44100;
const input_channels = 0;
const output_channels = 2;

pub const AudioSystem = struct {
    saw_generator: SawGenerator,

    pub fn init(self: *@This()) !void {
        self.saw_generator.init();

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
            SawGenerator.callback,
            &self.saw_generator,
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
        _ = self;

        const err = c.Pa_Terminate();
        if (err != c.paNoError) {
            // TODO
            // return error.PortAudioDeinit;
            unreachable;
        }
    }
};
