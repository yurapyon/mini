import type { Component } from 'solid-js';
import { TitleBar } from "./components/TitleBar";
import { Documentation } from "./components/documentation/Documentation";
import { init as initMini } from "./lib/Mini";

const Terminal = () => {
  return <div class="bg-[#000010] text-xs flex flex-col" style={{
    width: "64ch"
  }}>
    <div class="min-h-0 grow">
      Console
    </div>
  </div>;
}

const App: Component = () => {
  initMini();
  return (
    <div class="w-screen h-screen flex flex-col font-mono bg-[#080808] text-white">
      <TitleBar />
      <div class="w-full min-h-0 grow flex flex-row">
        <Documentation />
        <Terminal />
      </div>
    </div>
  );
};

export default App;
