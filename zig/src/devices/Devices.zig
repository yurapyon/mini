const vm = @import("../mini.zig");

const System = @import("system.zig").System;

pub const Devices = struct {
    system: System,

    pub fn activate(self: *@This(), mini: *vm.MiniVM, device_id: u8) void {
        switch (device_id) {
            0x0 => {
                self.system.onActivate(mini);
            },
            else => {},
        }
    }
};
