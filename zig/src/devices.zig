const vm = @import("vm.zig");

pub fn Devices(comptime start_addr: vm.Cell) type {
    return struct {
        // need a ptr to the vm to push things to the stack
        memory: vm.mem.CellAlignedMemory,

        pub fn init(self: @This(), memory: vm.mem.CellAlignedMemory) void {
            self.memory = memory;
        }

        pub fn store(self: *@This(), value: vm.Cell, addr: vm.Cell) vm.Error!void {
            const cell_ptr = (try vm.mem.cellAt(self.memory[start_addr..], addr));
            cell_ptr.* = value;
        }

        pub fn storeAdd(self: *@This(), value: vm.Cell, addr: vm.Cell) vm.Error!void {
            const cell_ptr = (try vm.mem.cellAt(self.memory[start_addr..], addr));
            cell_ptr.* +%= value;
        }

        pub fn fetch(self: *@This(), addr: vm.Cell) vm.Error!void {
            const cell_ptr = (try vm.mem.cellAt(self.memory[start_addr..], addr));
            // TODO
            _ = cell_ptr;
        }
    };
}
