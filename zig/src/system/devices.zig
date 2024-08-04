const vm = @import("../mini.zig");

const DeviceStore = packed struct(vm.Cell) {
    value: u8,
    sub_addr: u4,
    main_addr: u4,
};

const DeviceStoreAdd = packed struct(vm.Cell) {
    value: i8,
    sub_addr: u4,
    main_addr: u4,
};

const DeviceFetch = packed struct(u8) {
    sub_addr: u4,
    main_addr: u4,
};

fn nop() void {}

const DeviceDefinition = struct {
    store: *const fn () void = nop,
    storeAdd: *const fn () void = nop,
    fetch: *const fn () void = nop,
    poll: *const fn () void = nop,
};

const devices = [16]DeviceDefinition{
    .{},
    .{},
    .{},
    .{},

    .{},
    .{},
    .{},
    .{},

    .{},
    .{},
    .{},
    .{},

    .{},
    .{},
    .{},
    .{},
};

pub fn Devices(comptime start_addr: vm.Cell) type {
    _ = start_addr;
    return struct {
        mini: *vm.MiniVM,

        pub fn init(self: @This(), mini: vm.MiniVM) void {
            self.mini = mini;
        }

        pub fn store(self: *@This(), cell: vm.Cell) vm.Error!void {
            _ = self;
            const store_cell = @as(DeviceStore, @bitCast(cell));
            devices[store_cell.main_addr].store();
        }

        pub fn storeAdd(self: *@This(), cell: vm.Cell) vm.Error!void {
            _ = self;
            const store_add_cell = @as(DeviceStore, @bitCast(cell));
            devices[store_add_cell.main_addr].storeAdd();
        }

        pub fn fetch(self: *@This(), cell: vm.Cell) vm.Error!vm.Cell {
            _ = self;
            const fetch_cell = @as(DeviceStore, @bitCast(cell));
            devices[fetch_cell.main_addr].fetch();
            return 0xbeef;
        }

        pub fn poll(self: *@This()) vm.Error!?vm.Cell {
            _ = self;
            return null;
        }
    };
}

// ===

const console = struct {
    fn store(_: *vm.MiniVM, _: u4, _: u8) void {}
};
