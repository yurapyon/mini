const MiniVM = @import("../MiniVM.zig").MiniVM;
const System = @import("System.zig").System;

pub const Devices = struct {
    system: System,

    pub fn activate(self: *@This(), vm: *MiniVM, device_id: u8) void {
        switch (device_id) {
            0x0 => {
                self.system.onActivate(vm);
            },
            else => {},
        }
    }
};
