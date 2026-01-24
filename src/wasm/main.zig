const std = @import("std");

const mini = @import("mini");
const kernel = mini.kernel;
const Kernel = kernel.Kernel;
const Cell = kernel.Cell;
const FFI = kernel.FFI;
const Accept = kernel.Accept;

// ===

const allocator = std.heap.wasm_allocator;

var global_k: Kernel = undefined;
var forth_mem: mini.mem.MemoryPtr = undefined;
var ext_lookup: []u8 = undefined;
var image_mem: []u8 = undefined;
var script_mem: []u8 = undefined;

export fn allocateForthMemory() [*]u8 {
    forth_mem = mini.mem.allocateForthMemory(allocator) catch unreachable;
    return @ptrCast(forth_mem);
}

export fn allocateImageMemory(size: usize) [*]u8 {
    image_mem = mini.mem.allocate(allocator, size) catch unreachable;
    return @ptrCast(image_mem.ptr);
}

export fn allocateScriptMemory(size: usize) [*]u8 {
    script_mem = mini.mem.allocate(allocator, size) catch unreachable;
    return @ptrCast(script_mem.ptr);
}

export fn allocateExtLookupMemory() [*]u8 {
    ext_lookup = mini.mem.allocate(allocator, 128) catch unreachable;
    return @ptrCast(ext_lookup.ptr);
}

// ===

extern fn wasmPrint(usize) void;

export fn kPop() Cell {
    return global_k.data_stack.popCell();
}

export fn kPush(value: Cell) void {
    global_k.data_stack.pushCell(value);
}

export fn kPause() void {
    global_k.pause();
}

export fn kUnpause() void {
    global_k.unpause();
}

export fn kExecute() void {
    // TODO handle errors
    global_k.execute() catch unreachable;
}

extern fn jsEmit(u8) void;
extern fn jsStartRead(Cell, Cell) void;
extern fn jsFFICallback(Cell) void;
extern fn jsFFILookup(usize) isize;

fn emit(char: u8, _: ?*anyopaque) void {
    jsEmit(char);
}

fn accept(_: *Kernel, _: ?*anyopaque, buf_addr: Cell, buf_len: Cell) Accept.Error!Cell {
    jsStartRead(buf_addr, buf_len);
    return 0;
}

fn ffiCallback(_: *Kernel, _: ?*anyopaque, ext_token: Cell) FFI.Error!void {
    jsFFICallback(ext_token);
}

fn ffiLookup(_: *Kernel, _: ?*anyopaque, name: []const u8) ?Cell {
    const len = @min(name.len, ext_lookup.len);
    @memcpy(ext_lookup[0..len], name[0..len]);

    const code = jsFFILookup(name.len);
    // TODO check maxint
    if (code < 0) {
        return null;
    } else {
        return @intCast(code);
    }
}

// NOTE
// Frees image and script mem
//   TODO maybe don't do this
// TODO handle kernel errors
export fn run() void {
    global_k.init(forth_mem);

    global_k.loadImage(image_mem);
    allocator.free(image_mem);

    global_k.setFFIClosure(.{
        .callback = ffiCallback,
        .lookup = ffiLookup,
        .userdata = null,
    });

    global_k.clearAcceptClosure();
    global_k.setEmitClosure(.{
        .callback = emit,
        .userdata = null,
    });

    global_k.evaluate(script_mem) catch unreachable;
    allocator.free(script_mem);

    global_k.setAcceptClosure(.{
        .callback = accept,
        .userdata = null,
        .is_async = true,
    });
    global_k.initForth();
    global_k.execute() catch unreachable;
}

export fn deinit() void {
    // TODO
    // return 0;
}
