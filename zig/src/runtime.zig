pub const mem = @import("memory.zig");
pub const utils = @import("utils.zig");

const vm = @import("vm.zig");
const dictionary = @import("dictionary.zig");

pub const Cell = u16;

pub fn cellFromBoolean(value: bool) Cell {
    return if (value) 0xffff else 0;
}

pub fn isTruthy(value: Cell) bool {
    return value != 0;
}

pub const Error = error{
    ExternalPanic,
} || vm.Error || mem.Error;

pub const max_wordlists = 2;

pub const MainMemoryLayout = utils.MemoryLayout(struct {
    here: Cell,
    latest: Cell,
    context: Cell,
    wordlists: [2]Cell,
    state: Cell,
    base: Cell,
    input_buffer: [128]u8,
    input_buffer_at: Cell,
    input_buffer_len: Cell,
    dictionary_start: u0,
});

pub const Runtime = struct {
    vm: vm.VM,
    dictionary: dictionary.Dictionary,
    memory: mem.Memory,
};

test "runtime" {
    const r: Runtime = undefined;
    _ = r;
}
