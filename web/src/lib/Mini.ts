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
  const STARTUP_FILEPATH = "/mini/startup.mini.fth";

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

  const startup_response = await fetch(STARTUP_FILEPATH);
  const startup = await startup_response.bytes();

  WebAssembly
    .instantiateStreaming(fetch(WASM_FILEPATH), importObject)
    .then((result) => {
      const {
        allocateForthMemory,
        allocateImageMemory,
        allocateScriptMemory,
        evaluateScript
      } = result.instance.exports;

      const forth_ptr = allocateForthMemory();
      const image_ptr = allocateImageMemory(image.byteLength);
      const script_ptr = allocateScriptMemory(startup.byteLength);

      var wasm_mem = new Uint8Array(memory.buffer);
      wasm_mem.set(image, image_ptr);
      wasm_mem.set(startup, script_ptr);

      result.instance.exports.init();

      const forthEval = (str) => {
        const utf8 = new TextEncoder();
        const bytes = utf8.encode(str);

        const script_ptr = allocateScriptMemory(bytes.byteLength);

        var wasm_mem = new Uint8Array(memory.buffer);
        wasm_mem.set(bytes, script_ptr);

        evaluateScript();
      };

      forthEval("words cr ashy");
  });
}

export const init = () => {
  initWasm();
};

export const deinit = () => {
};

