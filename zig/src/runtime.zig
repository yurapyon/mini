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

pub const Memory align(@alignOf(Cell)) = [64 * 1024]u8;

const Device = [16]u8;

const MainMemoryLayout = utils.MemoryLayout(struct {
    device_memory: [16]Device,
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
}, Cell);

const DeviceMemoryLayout = utils.MemoryLayout(struct {
    forth: Device,
    _: [15]Device,
}, Cell);

pub const Runtime = struct {
    vm: vm.VM,
    dictionary: dictionary.Dictionary,
    memory: Memory,
};

test "runtime" {
    const r: Runtime = undefined;
    _ = r;
}
