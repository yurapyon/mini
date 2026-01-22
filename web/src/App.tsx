import { createResource, createEffect, createSignal, Index } from "solid-js";
import type { Component } from 'solid-js';
import { TitleBar } from "./components/TitleBar";
import { Documentation } from "./components/documentation/Documentation";
import { fetchMini } from "./lib/mini";

import { Terminal } from "./lib/console";

const terminal = new Terminal();

const TerminalComponent = (props) => {
  const [history, setHistory] = createSignal([]);
  const [cmd, setCmd] = createSignal("");

  createEffect(()=>{
    if (props.mini()) {
      props.mini().addExternal("put-xy", () => {
        const y = props.mini().kernel.pop();
        const x = props.mini().kernel.pop();
        const ch = props.mini().kernel.pop();
        terminal.putXY(ch, x, y);
      });
    }
  });

  return <div
    class="bg-[#000010] text-xs flex flex-col"
    style={{
      width: terminal.width + "ch",
      height: terminal.height + "lh",
    }}
    tabIndex="0"
    on:click={()=>{
      // props.mini().run("1 2 3 put-xy");
      console.log("asdf");
      props.mini().repl();
      console.log("asdf after");
    }}
    on:keydown={(ev)=>{
      ev.preventDefault();
      const c = cmd();
      if (ev.key === "Enter") {
        if (c.length > 0) {
          console.log("exec: " + c);
          props.mini().run(c);
          setHistory((p)=>[c, ...p]);
          setCmd("");
        }
      } else if (ev.key === "Backspace") {
        setCmd((p)=>p.slice(0, p.length-1));
      } else if (ev.key !== "Shift") {
        setCmd((p)=>p+ev.key);
      }
    }}
  >
    <div class="h-[1lh]">
      {cmd()}
    </div>
    <Index each={history()}>
      {(line)=>{
        return (
          <div>
            {line()}
          </div>
        );
      }}
    </Index>
  </div>;
}

/*
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
*/

const App: Component = () => {
  const [mini] = createResource(fetchMini);

  return (
    <div class="w-screen h-screen flex flex-col font-mono bg-[#202020] text-white">
      <TitleBar />
      <TerminalComponent mini={mini} />
        {/*
      <div class="w-full min-h-0 grow flex flex-row">
        <Documentation />
      </div>
      <Show when={mini()}>
        <Btn mini={mini()} />
      </Show>
          */}
    </div>
  );
};

export default App;
