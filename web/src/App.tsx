import { createResource } from "solid-js";
import type { Component } from 'solid-js';
import { TitleBar } from "./components/TitleBar";
import { Documentation } from "./components/documentation/Documentation";
import { fetchMini } from "./lib/mini";

const Terminal = () => {
  return <div class="bg-[#000010] text-xs flex flex-col" style={{
    width: "64ch"
  }}>
    <div class="min-h-0 grow">
      Console
    </div>
  </div>;
}

const Btn = (props) => {
  props.mini.addCallback(0, () => {
    console.log("asdf");
  });
  return (
    <button on:click={()=>{
      props.mini.run("0 js");
    }}>
      hi
    </button>
  );
}

const App: Component = () => {
  const [mini] = createResource(fetchMini);
  return (
    <div class="w-screen h-screen flex flex-col font-mono bg-[#080808] text-white">
      <TitleBar />
      <div class="w-full min-h-0 grow flex flex-row">
        <Documentation />
        <Terminal />
      </div>
      <Show when={mini()}>
        <Btn mini={mini()} />
      </Show>
    </div>
  );
};

export default App;
