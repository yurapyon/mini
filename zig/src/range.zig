const vm = @import("mini.zig");

pub const Range = struct {
    start: vm.Cell,
    end: vm.Cell,

    pub fn sizeExclusive(self: @This()) usize {
        return self.end - self.start;
    }

    pub fn alignedTo(self: @This(), alignment: usize) bool {
        return self.start % alignment == 0 and self.end % alignment == 0;
    }
};

test "ranges" {
    //
}
