const fs = require('fs');

const wasm_filepath = process.argv[2];
const source = fs.readFileSync(wasm_binary);
const wasm_bin = new Uint8Array(source);

const MEMORY_PAGE_COUNT = 4;

const memory = new WebAssembly.Memory({
  initial: MEMORY_PAGE_COUNT,
  maximum: MEMORY_PAGE_COUNT,
});

const importObject = {
  env: {
    wasmPrint: (result) => {
      console.log("zig: ", result);
    },
    callJs: (id) => {
      console.log("ext: ", id);
    },
    memory: memory,
  }
};

WebAssembly.instantiate(wasm_bin, importObject).then((result) => {
  const arr = new Uint8Array(memory.buffer);

  const init = result.instance.exports.init;
  const deinit = result.instance.exports.deinit;
  const getKernelMemoryPtr = result.instance.exports.getKernelMemoryPtr

  init();

  const miniMemOffset = getKernelMemoryPtr();
  const mem = arr.slice(
      miniMemOffset,
      miniMemOffset + 64 * 1024
  );
  console.log(mem[0], miniMemOffset, arr)

  // TODO copy image into forth memory

  deinit();
});

