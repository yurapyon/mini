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
var temp_mem: []u8 = undefined;

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

export fn allocateForthMemory() [*]u8 {
    forth_mem = mini.mem.allocateForthMemory(allocator) catch unreachable;
    return @ptrCast(forth_mem);
}

export fn allocateTempMemory(size: usize) [*]u8 {
    temp_mem = mini.mem.allocate(allocator, size) catch unreachable;
    return @ptrCast(temp_mem.ptr);
}

extern fn wasmPrint(usize) void;
extern fn jsEmit(u8) void;

fn emitStdOut(char: u8, _: ?*anyopaque) void {
    jsEmit(char);
}

export fn init() void {
    k.init(forth_mem);

    k.loadImage(temp_mem);
    allocator.free(temp_mem);

    k.setExternals(&exts) catch unreachable;

    k.clearAcceptClosure();
    k.setEmitClosure(emitStdOut, null);

    const str = "65 emit 66 emit 10 emit";
    k.evaluate(str) catch unreachable;

    // k.memory[0] = 123;

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
