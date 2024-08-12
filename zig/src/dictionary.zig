const runtime = @import("runtime.zig");
const Memory = runtime.Memory;

pub const Dictionary = struct {
    memory: *Memory,

    pub fn find(str: []const u8) void {
        _ = str;
    }

    pub fn define(word: []const u8) void {
        _ = word;
    }
};
