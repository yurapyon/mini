const consoleBuffer = [];

const putc = (char) => {
  if (char === 10) {
    const str = String.fromCharCode(...consoleBuffer);
    console.log(str)
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
  const offsets = {
    forth: 0,
    extLookup: 0,
  };

  const kernel = {
    pop: null,
    push: null,
    pause: null,
    unpause: null,
    execute: null,
    resume: null,
  };

  let emitCallback = () => {};
  const setEmitCallback = (cb) => {
    emitCallback = cb;
  }

  const externals = []

  const readQueue = [];
  const readDestination = {
    addr: 0,
    maxLen: 0,
  };

  const memory = new WebAssembly.Memory({
    initial: 20,
  });

  const utf8Encode = new TextEncoder();

  const readToForth = (addr, maxLen, str) => {
    const wasm_mem = new Uint8Array(memory.buffer);

    const bytes = utf8Encode.encode(str);
    wasm_mem.set(bytes, offsets.forth + addr);

    kernel.push(str.length);
  };

  const addToReadQueue = (lines: string[]) => {
    const shouldResume = readQueue.length === 0 && lines.length > 0;
    readQueue.push(...lines);

    if (shouldResume) {
      readToForth(
        readDestination.addr,
        readDestination.maxLen,
        readQueue.shift()
      );
      kernel.resume();
    }
  }

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
        const chars = wasm_mem.slice(
          offsets.extLookup,
          offsets.extLookup + len
        );
        const str = String.fromCharCode(...chars);

        const idx = externals.findIndex((ext) => ext.name === str);
        return idx;
      },
      jsEmit: (ch) => {
        emitCallback(ch)
      },
      jsStartRead: (addr, maxLen) => {
        readDestination.addr = addr;
        readDestination.maxLen = maxLen;

        let nextLine = readQueue.shift()
        if (nextLine !== undefined) {
          readToForth(addr, maxLen, nextLine)
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
    addToReadQueue(lines)
  })

  const addExternal = (extName, fn) => {
    externals.push({ name: extName, fn, });
    addToReadQueue(["external " + extName]);
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

      offsets.forth = allocateForthMemory();
      const image_ptr = allocateImageMemory(image.byteLength);
      const script_ptr = allocateScriptMemory(startup.byteLength);
      offsets.extLookup = allocateExtLookupMemory();

      let wasm_mem = new Uint8Array(memory.buffer);
      wasm_mem.set(image, image_ptr);
      wasm_mem.set(startup, script_ptr);

      setEmitCallback(putc);
      run();

      return {
        addExternal,
        setEmitCallback,
        kernel,
      }
  });

  return mini;
}
