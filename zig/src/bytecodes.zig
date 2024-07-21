const MiniVM = @import("MiniVM.zig").MiniVM;

pub const bytecodes = struct {
    pub fn exit(_: *MiniVM) void {}
};
