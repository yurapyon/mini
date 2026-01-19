const std = @import("std");

const mini = @import("mini");
const kernel = mini.kernel;
const Kernel = kernel.Kernel;
const Cell = kernel.Cell;

const externals = mini.externals;
const External = externals.External;

// ===

var k: Kernel = undefined;

// var mini_mem = std.mem.zeroes(mini.mem.Memory);

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

// TODO
// wasm startup file
// wasm externals

extern fn wasmPrint(usize) void;

export fn init() mini.mem.MemoryPtr {
    const allocator = std.heap.wasm_allocator;
    const m = mini.mem.allocateForthMemory(allocator) catch unreachable;
    k.init(m);
    k.setExternals(&exts) catch unreachable;

    m[0] = 123;

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

    return m;
}

export fn deinit() void {
    // return 0;
}
