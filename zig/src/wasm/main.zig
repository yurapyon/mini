const mini = @import("mini");

// TODO
// wasm startup file
// wasm externals

extern fn read() u8;

export fn init() u8 {
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
    return 1;
}

export fn deinit() u8 {
    return 0;
}
