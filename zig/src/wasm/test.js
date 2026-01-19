const wasm = process.argv[2];

const fs = require('fs');
const source = fs.readFileSync(wasm);
const typedArray = new Uint8Array(source);

WebAssembly.instantiate(typedArray, {
  env: {
    read: (result) => {
      return 10;
    }
  }}).then((result) => {
    const init = result.instance.exports.init;
    const deinit = result.instance.exports.deinit;

    const a = init();
    const b = deinit();
    console.log(a, b);
});

