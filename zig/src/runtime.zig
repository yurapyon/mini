const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const builtin = @import("builtin");

const mem = @import("memory.zig");
const MemoryPtr = mem.MemoryPtr;

const MemoryLayout = @import("utils/memory-layout.zig").MemoryLayout;

const register = @import("register.zig");
const Register = register.Register;

const externals = @import("externals.zig");
const External = externals.External;

// ===

comptime {
    const native_endianness = builtin.target.cpu.arch.endian();
    if (native_endianness != .little) {
        // TODO i'm not sure this is strictly required
        @compileError("native endianness must be .little");
    }
}

pub const Cell = u16;
pub const DoubleCell = u32;
pub const SignedCell = i16;

pub fn cellFromBoolean(value: bool) Cell {
    return if (value) 0xffff else 0;
}

pub fn isTruthy(value: Cell) bool {
    return value != 0;
}
