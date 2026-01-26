const consoleBuffer = [];

const putc = (char) => {
  if (char === 10) {
    const str = String.fromCharCode(...consoleBuffer);
    console.log(str);
    consoleBuffer.length = 0;
  } else {
    consoleBuffer.push(char);
  }
};

enum Filepaths {
  WASM = "/mini/mini-wasm.wasm",
  IMAGE = "/mini/precompiled.mini.bin",
  STARTUP = "/mini/startup.mini.fth",
}

export const fetchMini = async () => {
  const offsets = {
    forth: 0,
    image: 0,
    script: 0,
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
  };

  const externals = [];

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
  };

  const importObject = {
    env: {
      wasmPrint: (result) => {
        console.log("zig: ", result);
      },
      jsFFICallback: (id) => {
        externals[id].fn();
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
        emitCallback(ch);
      },
      jsStartRead: (addr, maxLen) => {
        readDestination.addr = addr;
        readDestination.maxLen = maxLen;

        let nextLine = readQueue.shift();
        if (nextLine !== undefined) {
          readToForth(addr, maxLen, nextLine);
        } else {
          kernel.pause();
        }
      },
      memory: memory,
    },
  };

  document.addEventListener("mini.read", (e) => {
    const str = e.detail;
    const lines = str.split("\n");
    addToReadQueue(lines);
  });

  const addExternal = (extName, fn) => {
    externals.push({ name: extName, fn });
    addToReadQueue(["external " + extName]);
    console.log("ext added:", extName);
  };

  const image_response = await fetch(Filepaths.IMAGE);
  const image = await image_response.bytes();

  const startup_response = await fetch(Filepaths.STARTUP);
  const startup = await startup_response.bytes();

  const calScript = await fetch("/mini/scripts/cal.mini.fth").then(
    (response) => {
      if (response.ok) {
        return response.text();
      } else {
        const err = new Error("Couldnt get file");
        console.error(err);
        return "";
      }
    }
  );

  const initJsBindings = () => {
    addExternal("y/m/d", () => {
      const date = new Date();
      const year = date.getFullYear();
      const month = date.getMonth() + 1;
      const day = date.getDate();
      kernel.push(year);
      kernel.push(month);
      kernel.push(day);
    });

    addExternal("h/m/s", () => {
      const date = new Date();
      const hours = date.getHours();
      const minutes = date.getMinutes();
      const seconds = date.getSeconds();
      kernel.push(hours);
      kernel.push(minutes);
      kernel.push(seconds);
    });

    addExternal("sleep", () => {
      const time = m.kernel.pop();
      kernel.pause();
      setTimeout(() => {
        kernel.resume();
      }, time);
    });

    document.dispatchEvent(
      new CustomEvent("mini.read", {
        detail: calScript,
      })
    );

    const timeScript = `
      : 24>12      12 mod dup 0= if drop 12 then ;
      : time       h/m/s flip 24 mod flip ;
      : 00:#       # # drop ':' hold ;
      : .time24    <# 00:# 00:# # # #> type ;
      : .time12hm  drop <# 00:# 24>12 # # #> type ;
      : this-month y/m/d drop swap ;
    `;

    document.dispatchEvent(
      new CustomEvent("mini.read", {
        detail: timeScript,
      })
    );
  };

  const mini = await WebAssembly.instantiateStreaming(
    fetch(Filepaths.WASM),
    importObject
  ).then((result) => {
    const {
      main,
      allocateForthMemory,
      allocateImageMemory,
      allocateScriptMemory,
      allocateExtLookupMemory,
      kPop,
      kPush,
      kPause,
      kUnpause,
      kExecute,
      reset: mReset,
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
    offsets.image = allocateImageMemory(image.byteLength);
    offsets.script = allocateScriptMemory(startup.byteLength);
    offsets.extLookup = allocateExtLookupMemory();

    let wasm_mem = new Uint8Array(memory.buffer);
    wasm_mem.set(image, offsets.image);
    wasm_mem.set(startup, offsets.script);

    setEmitCallback(putc);
    main();

    const reset = () => {
      externals.length = 0;
      mReset();
      initJsBindings();
    };

    return {
      addExternal,
      setEmitCallback,
      kernel,
      reset,
    };
  });

  await initJsBindings();

  return mini;
};
