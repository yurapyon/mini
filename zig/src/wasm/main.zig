const std = @import("std");

const mini = @import("mini");
const kernel = mini.kernel;
const Kernel = kernel.Kernel;

// ===

var k: Kernel = undefined;

export fn getKernelMemory() [*]u8 {
    return @ptrCast(&k.memory);
}

// TODO
// wasm startup file
// wasm externals

extern fn wasmPrint(usize) void;

export fn init() void {
    // const allocator = std.heap.wasm_allocator;

    // TODO memory error
    // k.init() catch unreachable;

    // k.memory[0] = 123;

    // if no system ===

    // create kernel
    // load precompile image into kernel
    // register externals

    // clear accept closure
    // set emit closure
    // read in startup file
    // read in other files

    // set accept closure to read from stdin
    // run forth loop
    // return 1;
}

export fn deinit() void {
    // return 0;
}
