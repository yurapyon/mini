import type { Component } from 'solid-js';
import { TitleBar } from "./components/TitleBar";

const ScriptEditor = () => {
  return <div class="bg-[#201010] text-sm shrink-0" style={{
    width: "64ch"
  }}>
    Script editor
  </div>;
}

const Documentation = () => {
  return <div class="bg-[#102010] text-sm" style={{
    width: "64ch"
  }}>
    Documentation
  </div>;
}

const Terminal = () => {
  return <div class="bg-[#000010] text-sm shrink-0 flex flex-col" style={{
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
