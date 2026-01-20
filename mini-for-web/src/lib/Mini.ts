const consoleBuffer = [];

const putc = (char) => {
  if (char === 10) {
    const str = String.fromCharCode(...consoleBuffer);
    console.log(str);
    consoleBuffer.length = 0;
  } else {
    consoleBuffer.push(char);
  }
}


const initWasm = async () => {
  const WASM_FILEPATH = "/mini/mini-wasm.wasm";
  const IMAGE_FILEPATH = "/mini/precompiled.mini.bin";

  const memory = new WebAssembly.Memory({
    initial: 20,
    // initial: MEMORY_PAGE_COUNT,
    // maximum: MEMORY_PAGE_COUNT,
  });

  const importObject = {
    env: {
      wasmPrint: (result) => {
        console.log("zig: ", result);
      },
      callJs: (id) => {
        console.log("ext: ", id);
      },
      jsEmit: (ch) => {
        putc(ch);
      },
      memory: memory,
    }
  };

  const image_response = await fetch(IMAGE_FILEPATH);
  const image = await image_response.bytes();

  WebAssembly
    .instantiateStreaming(fetch(WASM_FILEPATH), importObject)
    .then((result) => {
      const {
        allocateForthMemory,
        allocateTempMemory,
      } = result.instance.exports;

      const forth_ptr = allocateForthMemory();
      const image_ptr = allocateTempMemory(image.byteLength);


      var wasm_mem = new Uint8Array(memory.buffer);
      wasm_mem.set(image, image_ptr);
      result.instance.exports.init();

      console.log(
        wasm_mem,
        wasm_mem.slice(forth_ptr, (forth_ptr + 256)),
        wasm_mem.slice(image_ptr, (image_ptr + 256)),
      );
  });
}

export const init = () => {
  initWasm();
};

export const deinit = () => {
};

