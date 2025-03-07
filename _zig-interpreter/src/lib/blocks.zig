const std = @import("std");

const runtime = @import("../runtime.zig");
const Runtime = runtime.Runtime;
const Cell = runtime.Cell;

const mem = @import("../memory.zig");

const externals = @import("../externals.zig");
const External = externals.External;

const dictionary = @import("../dictionary.zig");
const Dictionary = dictionary.Dictionary;

// ===

const blocks_file = @embedFile("blocks.mini.fth");

const ExternalId = enum(Cell) {
    bwrite,
    bread,
    _max,
    _,
};

fn externalsCallback(rt: *Runtime, token: Cell, userdata: ?*anyopaque) External.Error!bool {
    const self = @as(*Blocks, @ptrCast(@alignCast(userdata)));

    const external_id = @as(ExternalId, @enumFromInt(token - self.start_token));

    switch (external_id) {
        .bwrite => {
            const addr = rt.data_stack.popCell();
            const block_id = rt.data_stack.popCell();
            const buffer = try mem.constSliceFromAddrAndLen(
                rt.memory,
                addr,
                Blocks.block_size,
            );
            // TODO don't catch unreachable
            self.blockToStorage(block_id, buffer) catch unreachable;
        },
        .bread => {
            const addr = rt.data_stack.popCell();
            const block_id = rt.data_stack.popCell();
            const buffer = try mem.sliceFromAddrAndLen(
                rt.memory,
                addr,
                Blocks.block_size,
            );
            // TODO don't catch unreachable
            self.storageToBlock(block_id, buffer) catch unreachable;
        },
        else => return false,
    }
    return true;
}

pub const Blocks = struct {
    const block_size = 1024;
    const block_count = 256;

    rt: *Runtime,
    start_token: Cell,
    image_filepath: []const u8,

    pub fn init(self: *@This(), rt: *Runtime, image_filepath: []const u8) void {
        self.rt = rt;
        // TODO copy string passed in
        self.image_filepath = image_filepath;
    }

    pub fn initLibrary(self: *@This(), start_token: Cell) !Cell {
        const external = External{
            .callback = externalsCallback,
            .userdata = self,
        };
        const forth_vocabulary_addr = Dictionary.forth_vocabulary_addr;
        try self.rt.defineExternal(
            "bb.write",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.bwrite) + start_token,
        );
        try self.rt.defineExternal(
            "bb.read",
            forth_vocabulary_addr,
            @intFromEnum(ExternalId.bread) + start_token,
        );

        try self.rt.addExternal(external);

        self.start_token = start_token;

        try self.rt.processBuffer(blocks_file);

        return @intFromEnum(ExternalId._max) + self.start_token;
    }

    pub fn storageToBlock(
        self: *@This(),
        block_id: Cell,
        buffer: []u8,
    ) !void {
        if (block_id > block_count) {
            return error.InvalidBlockId;
        }

        // TODO check block size

        var file = try std.fs.cwd().openFile(
            self.image_filepath,
            .{ .mode = .read_only },
        );
        defer file.close();

        // TODO
        // check file size ?
        const seek_pt: usize = (block_id - 1) * block_size;
        try file.seekTo(seek_pt);
        _ = try file.read(buffer);
    }

    pub fn blockToStorage(
        self: *@This(),
        block_id: Cell,
        buffer: []const u8,
    ) !void {
        if (block_id > block_count) {
            return error.InvalidBlockId;
        }

        // TODO check block size

        var file = try std.fs.cwd().openFile(
            self.image_filepath,
            .{ .mode = .write_only },
        );
        defer file.close();

        // TODO
        // check file size ?
        const seek_pt: usize = (block_id - 1) * block_size;
        try file.seekTo(seek_pt);
        _ = try file.write(buffer);
    }
};
