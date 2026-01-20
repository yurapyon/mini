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

export const fetchMini = async () => {
  var ext_ptr = 0;

  const kernel = {
    pop: null,
    push: null,
  };

  const externals = [
    {
      name: "js",
      fn: ()=>{
        const value = kernel.pop()
        console.log("ext: ", value);
      }
    },
    {
      name: "js2",
      fn: ()=>{
        const value = kernel.pop()
        console.log("ext2: ", value);
      }
    }
  ];

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
      jsRead: (ch) => {
        // const val = 0;

        /*
        const p = new Promise((resolve) => {
          rl.resume();
          rl.on('line', (line) => {
            rl.pause();
            resolve(line);
          });
        });

        p.then((line)=>console.log("asdf", line));
        */

        // process.stdout.write(String.fromCharCode(ch));
      },
      memory: memory,
    }
  };

  const image_response = await fetch(IMAGE_FILEPATH);
  const image = await image_response.bytes();

  const startup_response = await fetch(STARTUP_FILEPATH);
  const startup = await startup_response.bytes();

  const mini = await WebAssembly
    .instantiateStreaming(fetch(WASM_FILEPATH), importObject)
    .then((result) => {
      const {
        allocateForthMemory,
        allocateImageMemory,
        allocateScriptMemory,
        allocateExtLookupMemory,
        evaluateScript,
        kPop,
        kPush,
      } = result.instance.exports;

      const forth_ptr = allocateForthMemory();
      const image_ptr = allocateImageMemory(image.byteLength);
      const script_ptr = allocateScriptMemory(startup.byteLength);
      ext_ptr = allocateExtLookupMemory();

      var wasm_mem = new Uint8Array(memory.buffer);
      wasm_mem.set(image, image_ptr);
      wasm_mem.set(startup, script_ptr);

      result.instance.exports.init();

      const run = (str) => {
        const utf8 = new TextEncoder();
        const bytes = utf8.encode(str);

        const script_ptr = allocateScriptMemory(bytes.byteLength);

        var wasm_mem = new Uint8Array(memory.buffer);
        wasm_mem.set(bytes, script_ptr);

        evaluateScript();
      };

      const addExternal = (extName, fn) => {
        externals.push({
          name: extName,
          fn,
        });
        run("external " + extName)
      };

      kernel.pop = kPop;
      kernel.push = kPush;

      run("external js")
      run("external js2")

      return {
        run,
        addExternal,
        kernel,
      }
  });

  return mini;
}
