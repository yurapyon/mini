const fs = require('fs');

const wasm_filepath = process.argv[2];
const source = fs.readFileSync(wasm_filepath);
const wasm_bin = new Uint8Array(source);

const image_filepath = process.argv[3];
const image = fs.readFileSync(image_filepath);
const image_bin = new Uint8Array(image);

const memory = new WebAssembly.Memory({
  initial: 20,
  // maximum: 100,
  // shared: true,
});

function inspectMemory() {
  const pageSize = 2 ** 16;

  console.log('pages:', memory.buffer.byteLength / pageSize);
  const memoryView = new Uint8Array(memory.buffer);
  const used = [];
  for (let i = 0; i < memoryView.length; i++) {
    if (memoryView[i]) {
      const start = i;

      while (true) {
        const maxLookForwardBytes = 300;
        const bytesLeft = memoryView.length - i;
        const lookForwardBytes = Math.min(maxLookForwardBytes, bytesLeft);
        const forwardView = new Uint8Array(memory.buffer, i, lookForwardBytes);
        if (forwardView.every((byte) => byte === 0)) break;

        i++;
      }

      used.push([start, i - start]);
    }
  }
  console.log(
    used.map(
      ([start, length]) =>
        `page:${Math.floor(start / pageSize)} offset:${start % pageSize} bytes:${length}`
    ),
    '\n'
  );
}


const importObject = {
  env: {
    wasmPrint: (result) => {
      console.log("zig: ", result);
    },
    callJs: (id) => {
      console.log("ext: ", id);
    },

    jsEmit: (ch) => {
      // console.log(String.fromCharCode(ch));
      process.stdout.write(String.fromCharCode(ch));
    },
    memory: memory,
  }
};


WebAssembly.instantiate(wasm_bin, importObject).then((result) => {
  const {
    allocateForthMemory,
    allocateTempMemory,
  } = result.instance.exports;

  inspectMemory();

  const forth_ptr = allocateForthMemory();
  const image_ptr = allocateTempMemory(image_bin.byteLength);

  inspectMemory();

  var wasm_mem = new Uint8Array(memory.buffer);
  wasm_mem.set(image_bin, image_ptr);
  result.instance.exports.init();

  inspectMemory();

  console.log(
    wasm_mem,
    wasm_mem.slice(forth_ptr, (forth_ptr + 256)),
    wasm_mem.slice(image_ptr, (image_ptr + 256)),
  );
});

