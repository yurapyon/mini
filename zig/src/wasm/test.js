const wasm = process.argv[2];

const fs = require('fs');
const source = fs.readFileSync(wasm);
const typedArray = new Uint8Array(source);


const imports = {
  env: {
    wasmPrint: (result) => {
      console.log("zig: ", result);
    },
    // memory: mini_memory,
  }
};

WebAssembly.instantiate(typedArray, imports).then((result) => {
  const init = result.instance.exports.init;
  const deinit = result.instance.exports.deinit;
  const getKernelMemory = result.instance.exports.getKernelMemory;

  init();

  const mem = new Uint8Array(getKernelMemory());
  console.log(getKernelMemory(), mem, mem[0])

  deinit();
});

