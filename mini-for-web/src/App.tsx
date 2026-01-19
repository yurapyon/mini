import type { Component } from 'solid-js';
import { TitleBar } from "./components/TitleBar";
import { Documentation } from "./components/documentation/Documentation";

const initWasm = () => {
  const WASM_FILEPATH = "/mini-wasm.wasm"

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

  WebAssembly.instantiateStreaming(fetch(WASM_FILEPATH), importObject).then((result) => {
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
}

const ScriptEditor = () => {
  return <div class="bg-[#201010] text-xs" style={{
    width: "64ch"
  }}>
    Script editor
  </div>;
}

const Terminal = () => {
  return <div class="bg-[#000010] text-xs flex flex-col" style={{
    width: "64ch"
  }}>
    <div class="min-h-0 grow">
      History
    </div>
    <div class="bg-[#101020]">
      Command line
    </div>
  </div>;
}

const App: Component = () => {
  initWasm();
  return (
    <div class="w-screen h-screen flex flex-col font-mono bg-[#080808] text-white">
      <TitleBar />
      <div class="w-full min-h-0 grow flex flex-row">
        <Documentation />
        <ScriptEditor />
        <Terminal />
      </div>
    </div>
  );
};

export default App;
