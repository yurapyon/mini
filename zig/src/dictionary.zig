const mem = @import("memory.zig");
const MemoryPtr = mem.MemoryPtr;

const runtime = @import("runtime.zig");
const MainMemoryLayout = runtime.MainMemoryLayout;

const Register = @import("register.zig").Register;

pub const Dictionary = struct {
    memory: MemoryPtr,

    here: Register(MainMemoryLayout.offsetOf("here")),
    latest: Register(MainMemoryLayout.offsetOf("latest")),
    context: Register(MainMemoryLayout.offsetOf("context")),
    wordlists: Register(MainMemoryLayout.offsetOf("wordlists")),

    pub fn find(str: []const u8) void {
        _ = str;
    }

    pub fn define(word: []const u8) void {
        _ = word;
    }
};
