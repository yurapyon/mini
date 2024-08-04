const vm = @import("mini.zig");
const Range = @import("range.zig").Range;
const Register = @import("register.zig").Register;

pub fn IOBuffer(
    comptime at_offset: vm.Cell,
    comptime range_: Range,
) type {
    return struct {
        comptime {
            // TODO move this and the checks in stack.zig to the Range struct
            if (range.start >= range.end) {
                @compileError("Invalid stack range");
            }
            if (!range.alignedTo(@alignOf(vm.Cell))) {
                @compileError("Stack range must be vm.Cell aligned");
            }
        }

        pub const range = range_;

        memory: vm.mem.CellAlignedMemory,
        buffer_at: Register(at_offset),
        requestRefill: *const fn () void,
        onFlush: *const fn (output: []const u8) void,

        pub fn flush() void {}
        pub fn reset() void {}
        pub fn commaC() void {}
        pub fn nextChar() void {}
        pub fn nextWord() void {}
        pub fn fill(input: []const u8) void {
            _ = input;
        }
    };
}
