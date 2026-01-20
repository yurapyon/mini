const std = @import("std");

const mini = @import("mini");
const kernel = mini.kernel;
const Kernel = kernel.Kernel;
const Cell = kernel.Cell;

const externals = mini.externals;
const External = externals.External;

// ===

const allocator = std.heap.wasm_allocator;

var k: Kernel = undefined;
var forth_mem: mini.mem.MemoryPtr = undefined;
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

// ===

extern fn callJs(Cell) void;
fn callJs_(k_: *Kernel, _: ?*anyopaque) External.Error!void {
    const value = k_.data_stack.popCell();
    callJs(value);
}

const exts = [_]External{
    .{
        .name = "js",
        .callback = callJs_,
        .userdata = null,
    },
};

extern fn wasmPrint(usize) void;

extern fn jsEmit(u8) void;
extern fn jsRead() u8;

fn emit(char: u8, _: ?*anyopaque) void {
    jsEmit(char);
}

fn accept(out: []u8, _: ?*anyopaque) error{CannotAccept}!Cell {
    _ = out;
    // TODO
    return 0;
}

// NOTE
// Frees image and script mem
//   TODO maybe don't do this
// TODO handle kernel errors
export fn init() void {
    k.init(forth_mem);

    k.loadImage(image_mem);
    allocator.free(image_mem);

    k.setExternals(&exts) catch unreachable;

    k.clearAcceptClosure();
    k.setEmitClosure(emit, null);

    k.evaluate(script_mem) catch unreachable;
    allocator.free(script_mem);

    // Start repl
    // k.setAcceptClosure(accept, null);
    // k.initForth();
    // k.execute() catch unreachable;

    // _ = jsRead();
    // _ = jsRead();

    // if no system ===

    // create kernel
    // register externals
    // load precompile image into kernel

    // clear accept closure
    // set emit closure
    // read in startup file
    // read in other files

    // set accept closure to read from stdin
    // run forth loop
    // return 1;

    // return m;
}

export fn deinit() void {
    // return 0;
}

export fn evaluateScript() void {
    k.evaluate(script_mem) catch unreachable;
    allocator.free(script_mem);
}
