const readline = require('readline');
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

rl.prompt();
rl.pause();

/*
const lines = [];
rl.on('line' (line) => {
  lines.push(line);
});
*/

const fs = require('fs');

const wasm_filepath = process.argv[2];
const source = fs.readFileSync(wasm_filepath);
const wasm_bin = new Uint8Array(source);

const image_filepath = process.argv[3];
const image = fs.readFileSync(image_filepath);
const image_bin = new Uint8Array(image);

const startup_filepath = "src/wasm/startup.mini.fth";
const startup = fs.readFileSync(startup_filepath);
const startup_bin = new Uint8Array(startup);

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
      process.stdout.write(String.fromCharCode(ch));
    },
    jsRead: (ch) => {
      // const val = 0;

      const p = new Promise((resolve) => {
        rl.resume();
        rl.on('line', (line) => {
          rl.pause();
          resolve(line);
        });
      });

      p.then((line)=>console.log("asdf", line));

      // process.stdout.write(String.fromCharCode(ch));
    },
    memory: memory,
  }
};

WebAssembly.instantiate(wasm_bin, importObject).then((result) => {
  const {
    allocateForthMemory,
    allocateImageMemory,
    allocateScriptMemory,
    evaluateScript
  } = result.instance.exports;

  const forth_ptr = allocateForthMemory();
  const image_ptr = allocateImageMemory(image_bin.byteLength);
  const script_ptr = allocateScriptMemory(startup_bin.byteLength);

  var wasm_mem = new Uint8Array(memory.buffer);

  wasm_mem.set(image_bin, image_ptr);
  wasm_mem.set(startup_bin, script_ptr);

  result.instance.exports.init();

  const forthEval = (str) => {
    const utf8 = new TextEncoder();
    const bytes = utf8.encode(str);

    console.log(bytes);

    const script_ptr = allocateScriptMemory(bytes.byteLength);

    var wasm_mem = new Uint8Array(memory.buffer);
    wasm_mem.set(bytes, script_ptr);

    console.log(wasm_mem.slice(script_ptr, script_ptr + 30));

    evaluateScript();
  };

  forthEval("words cr ashy");
  // forthEval("ashy");
});

