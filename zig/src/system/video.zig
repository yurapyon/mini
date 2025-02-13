const c = @import("c.zig");

const runtime = @import("../runtime.zig");
const Cell = runtime.Cell;

// ===

// 64k * 3 can max 512 x 384 x 8bit
const page_size = 64 * 1024;
const page_ct = 3;

pub const width = 512;
pub const height = 384;

// 256 color palette with 24bit color
const RGB = [3]u8;

pub const Video = struct {
    buffer: [page_size * page_ct]RGB,
    palette: [256]RGB,

    texture: c.GLuint,
    vbo: c.GLuint,
    vao: c.GLuint,
    prog: c.GLuint,

    pub fn init(self: *@This()) void {
        self.makeTexture();
        self.makeQuad();
        self.makeProgram();
        // TODO set uniforms
    }

    pub fn deinit(_: *@This()) void {
        // TODO
    }

    // ===

    fn makeTexture(self: *@This()) void {
        var tex: c.GLuint = undefined;
        c.glGenTextures(1, &tex);
        c.glBindTexture(c.GL_TEXTURE_2D, tex);

        c.glTexImage2D(
            c.GL_TEXTURE_2D,
            0,
            c.GL_RGB,
            width,
            height,
            0,
            c.GL_RGB,
            c.GL_UNSIGNED_BYTE,
            null,
        );

        // c.glGenerateMipmap(c.GL_TEXTURE_2D);
        c.glTexParameteri(
            c.GL_TEXTURE_2D,
            c.GL_TEXTURE_WRAP_S,
            c.GL_REPEAT,
        );
        c.glTexParameteri(
            c.GL_TEXTURE_2D,
            c.GL_TEXTURE_WRAP_T,
            c.GL_REPEAT,
        );
        c.glTexParameteri(
            c.GL_TEXTURE_2D,
            c.GL_TEXTURE_MIN_FILTER,
            c.GL_NEAREST,
        );
        c.glTexParameteri(
            c.GL_TEXTURE_2D,
            c.GL_TEXTURE_MAG_FILTER,
            c.GL_NEAREST,
        );

        c.glBindTexture(c.GL_TEXTURE_2D, 0);

        self.texture = tex;
    }

    fn makeQuad(self: *@This()) void {
        var vbo: c.GLuint = undefined;
        c.glGenBuffers(1, &vbo);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        const data = [_]f32{
            1.0, 1.0, 1.0, 1.0,
            0.0, 1.0, 0.0, 1.0,
            1.0, 0.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 0.0,
        };
        c.glBufferData(
            c.GL_ARRAY_BUFFER,
            @sizeOf(@TypeOf(data)),
            &data,
            c.GL_STATIC_DRAW,
        );
        self.vbo = vbo;
    }

    fn makeProgram(self: *@This()) void {
        _ = self;
    }

    // ===

    pub fn putPixel(
        self: *@This(),
        page: Cell,
        addr: Cell,
        palette_idx: u8,
    ) void {
        const color = self.palette[palette_idx];
        const page_at = page % page_ct;
        const buffer_color = self.buffer[page_at * page_size + addr][0..2];
        @memcpy(buffer_color, color);
    }

    pub fn setPalette(self: *@This(), at: u8, r: u8, g: u8, b: u8) void {
        self.palette[at][0] = r;
        self.palette[at][1] = g;
        self.palette[at][2] = b;
    }

    pub fn draw(self: *@This()) void {
        _ = self;
        // copy buffer to texture
        // show texture
    }
};

const gfx = struct {
    const vert_shader = @embedFile("shaders/vert.glsl");
    const frag_shader = @embedFile("shaders/frag.glsl");

    pub const shader = struct {
        pub fn create(str: []const u8, shader_type: c.GLenum) c.GLuint {
            const shd = c.glCreateShader(shader_type);
            if (shd == 0) {
                // TODO error
                return 0;
            }

            c.glShaderSource(
                shd,
                1,
                &[_]*const u8{@ptrCast(str.ptr)},
                &[_]c_int{@intCast(str.len)},
            );
            c.glCompileShader(shd);

            var info_len: c_int = 0;
            c.glGetShaderiv(shd, c.GL_INFO_LOG_LENGTH, &info_len);
            if (info_len != 0) {
                // TODO error
                // var buf = try heap_alloc.alloc(u8, @intCast(usize, info_len));
                // glGetShaderInfoLog(shader, info_len, null, buf.ptr);
                // std.debug.print("shader info:\n{s}", .{buf});
                // heap_alloc.free(buf);
            }

            var success: c_int = undefined;
            c.glGetShaderiv(shd, c.GL_COMPILE_STATUS, &success);
            if (success != c.GL_TRUE) {
                // TODO error
                return 0;
            }
            return shd;
        }

        pub fn deinit(shd: c.GLuint) void {
            // TODO
            _ = shd;
        }
    };

    pub const program = struct {
        pub fn create() c.GLuint {
            const vert = shader.create(vert_shader, c.GL_VERTEX_SHADER);
            const frag = shader.create(frag_shader, c.GL_FRAGMENT_SHADER);
            const shaders = [_]c.GLuint{
                vert,
                frag,
            };
            const prog = c.glCreateProgram();
            errdefer c.glDeleteProgram(prog);

            if (prog == 0) {
                // TODO handle error
                return 0;
            }

            for (shaders) |shd| {
                c.glAttachShader(prog, shd);
            }

            c.glLinkProgram(prog);

            var info_len: c_int = 0;
            c.glGetProgramiv(prog, c.GL_INFO_LOG_LENGTH, &info_len);
            if (info_len != 0) {
                // TODO handle error
                // var buf = try heap_alloc.alloc(u8, @intCast(usize, info_len));
                // glGetProgramInfoLog(program, info_len, null, buf.ptr);
                // std.debug.print("program info:\n{s}", .{buf});
                // heap_alloc.free(buf);
            }

            var success: c_int = undefined;
            c.glGetProgramiv(prog, c.GL_LINK_STATUS, &success);
            if (success != c.GL_TRUE) {
                // TODO handle error
                return 0;
            }

            return prog;
        }

        pub fn deinit(prog: c.GLuint) void {
            // TODO
            _ = prog;
        }
    };
};
