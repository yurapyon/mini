pub const kernel = @import("kernel.zig");
pub const mem = @import("memory.zig");
pub const externals = @import("externals.zig");

pub const utils = struct {
    const read_file = @import("utils/read-file.zig");
    pub const readFile = read_file.readFile;
    pub const writeFile = read_file.writeFile;

    const handles = @import("utils/handles.zig");
    pub const Handles = handles.Handles;

    pub const channel = @import("utils/channel.zig");

    pub const random = @import("utils/random.zig");
};
