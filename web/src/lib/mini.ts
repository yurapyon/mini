const consoleBuffer = [];

const putc = (char) => {
  if (char === 10) {
    const str = String.fromCharCode(...consoleBuffer);
    // TODO split this to lines?
    const ev = new CustomEvent("mini.print", {
      detail: str
    });
    document.dispatchEvent(ev);
    consoleBuffer.length = 0;
  } else {
    consoleBuffer.push(char);
  }
}

enum Filepaths {
  WASM = "/mini/mini-wasm.wasm",
  IMAGE = "/mini/precompiled.mini.bin",
  STARTUP = "/mini/startup.mini.fth",
}

export const fetchMini = async () => {
  let forth_ptr = 0;
  let ext_ptr = 0;

  const kernel = {
    pop: null,
    push: null,
    pause: null,
    unpause: null,
    execute: null,
    resume: null,
  };

  const externals = []

  const readQueue = [];

  const memory = new WebAssembly.Memory({
    initial: 20,
  });

  const utf8Encode = new TextEncoder();

  const readToForth = (addr, len, str) => {
    const wasm_mem = new Uint8Array(memory.buffer);

    const bytes = utf8Encode.encode(str);
    wasm_mem.set(bytes, forth_ptr + addr);

    kernel.push(str.length);
  };

  const importObject = {
    env: {
      wasmPrint: (result) => {
        console.log("zig: ", result);
      },
      jsFFICallback: (id) => {
        externals[id].fn()
      },
      jsFFILookup: (len) => {
        const wasm_mem = new Uint8Array(memory.buffer);
        const chars = wasm_mem.slice(ext_ptr, ext_ptr + len);
        const str = String.fromCharCode(...chars);

        const idx = externals.findIndex((ext) => ext.name === str);
        return idx;
      },
      jsEmit: (ch) => {
        putc(ch);
      },
      jsStartRead: (addr, len) => {
        let nextLine = readQueue.shift()
        if (nextLine !== undefined) {
          readToForth(addr, len, nextLine)
        } else {
          kernel.pause();
        }
      },
      memory: memory,
    }
  };

  document.addEventListener("mini.read", (e)=>{
    const str = e.detail
    const lines = str.split("\n")
    readQueue.push(...lines);
    kernel.resume();
  })

  const addExternal = (extName, fn) => {
    externals.push({
      name: extName,
      fn,
    });
    readQueue.push("external " + extName);
    kernel.resume();
    console.log("ext added:", extName);
  };

  const image_response = await fetch(Filepaths.IMAGE);
  const image = await image_response.bytes();

  const startup_response = await fetch(Filepaths.STARTUP);
  const startup = await startup_response.bytes();

  const mini = await WebAssembly
    .instantiateStreaming(fetch(Filepaths.WASM), importObject)
    .then((result) => {
      const {
        run,
        allocateForthMemory,
        allocateImageMemory,
        allocateScriptMemory,
        allocateExtLookupMemory,
        kPop,
        kPush,
        kPause,
        kUnpause,
        kExecute,
      } = result.instance.exports;

      // TODO
      // need a kernel.popString
      kernel.pop = kPop;
      kernel.push = kPush;
      kernel.pause = kPause;
      kernel.unpause = kUnpause;
      kernel.execute = kExecute;
      kernel.resume = () => {
        kUnpause();
        kExecute();
      };

      forth_ptr = allocateForthMemory();
      const image_ptr = allocateImageMemory(image.byteLength);
      const script_ptr = allocateScriptMemory(startup.byteLength);
      ext_ptr = allocateExtLookupMemory();

      let wasm_mem = new Uint8Array(memory.buffer);
      wasm_mem.set(image, image_ptr);
      wasm_mem.set(startup, script_ptr);

      run();

      return {
        addExternal,
        kernel,
      }
  });

  return mini;
}
