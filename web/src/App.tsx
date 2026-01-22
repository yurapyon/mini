import { createResource, createEffect, createSignal, Index } from "solid-js";
import type { Component } from 'solid-js';
import { TitleBar } from "./components/TitleBar";
import { Documentation } from "./components/documentation/Documentation";
import { fetchMini } from "./lib/mini";

import { Terminal } from "./lib/console";

const terminal = new Terminal();

const TerminalComponent = (props) => {
  const [history, setHistory] = createSignal([]);
  const pushLine = (str) => {
    setHistory((prev) => {
      const next = [...prev]
      if (next.length >= 300) {
        next.shift()
      }
      next.push(str)
      return next;
    });
  };

  const [cmd, setCmd] = createSignal("");

  createEffect(()=>{
    if (props.mini()) {
      props.mini().addExternal("put-xy", () => {
        const y = props.mini().kernel.pop();
        const x = props.mini().kernel.pop();
        const ch = props.mini().kernel.pop();
        terminal.putXY(ch, x, y);
      });

      document.addEventListener("mini.print", (e)=>{
        const str = e.detail
        pushLine(str);
      })

      props.mini().repl();

      const startingCmd = "ashy";

      pushLine(startingCmd)
      document.dispatchEvent(new CustomEvent("mini.read", {
        detail: startingCmd,
      }));
    }
  });

  return (
    <div
      class="bg-[#202020] focus:bg-[#000010] text-gray-500 focus:text-white text-xs flex flex-col-reverse overflow-scroll"
      style={{
        width: terminal.width + "ch",
        height: terminal.height + "lh",
      }}
      tabIndex="0"
      on:keydown={(ev)=>{
        ev.preventDefault();
        const c = cmd();
        if (ev.key === "Enter") {
          if (c.length > 0) {
            console.log("exec: " + c);
            pushLine(c);
            const ev = new CustomEvent("mini.read", {
              detail: c,
            });
            document.dispatchEvent(ev);
            setCmd("");
          }
        } else if (ev.key === "Backspace") {
          setCmd((p)=>p.slice(0, p.length-1));
        } else if (ev.key !== "Shift") {
          setCmd((p)=>p+ev.key);
        }
      }}
    >
      <pre class="h-[1lh] shrink-0">
        {cmd()}
      </pre>
      <Index each={history().toReversed()}>
        {(line)=>{
          return (
            <pre class="text-wrap">
              {line()}
            </pre>
          );
        }}
      </Index>
    </div>
  );
}

const App: Component = () => {
  const [mini] = createResource(fetchMini);

  return (
    <div class="w-screen h-screen flex flex-col font-mono bg-[#303030] text-white items-center">
      <TitleBar />
      <div class="flex flex-row gap-20 items-center grow min-h-0">
        <TerminalComponent mini={mini} />
        <div>
          <div>
            Click on the terminal to activate it
          </div>
          <div>
            Enter commands and press enter!
          </div>
          <div>
            Some commands to try: 'ashy' '0 256 dump' 'words cr'
          </div>
        </div>
      </div>
    </div>
  );
};

export default App;
