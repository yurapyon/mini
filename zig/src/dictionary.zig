const runtime = @import("runtime.zig");
const Memory = runtime.Memory;

pub const Dictionary = struct {
    memory: *Memory,
};
