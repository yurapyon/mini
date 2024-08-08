pub const mem = @import("memory.zig");

const vm = @import("vm.zig");
const dictionary = @import("dictionary.zig");

pub const Cell = u16;

pub const Error = error{} || mem.Error;

pub const Memory align(@alignOf(Cell)) = [64 * 1024]u8;

pub const Mini = struct {
    vm: vm.VM,
    dictionary: dictionary.Dictionary,
};
