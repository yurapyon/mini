import { createResource, createEffect, createSignal, Index } from "solid-js";
import type { Component } from 'solid-js';
import { TitleBar } from "./components/TitleBar";
import { Documentation } from "./components/documentation/Documentation";
import { fetchMini } from "./lib/mini";

import { Terminal } from "./lib/console";

const PROMPT = "mini> ";

const terminal = new Terminal();

// TODO
//   technically you should pause and resume for all async calls from forth
//   figure out a nice way to do this

const TerminalComponent = (props) => {
  const [cmd, setCmd] = createSignal("");

  createEffect(async ()=>{
    const m = props.mini
    if (m) {
      m.addExternal("y/m/d", ()=>{
        const date  = new Date();
        const year  = date.getFullYear();
        const month = date.getMonth() + 1;
        const day   = date.getDate();
        m.kernel.push(year)
        m.kernel.push(month)
        m.kernel.push(day)
      })
      await fetch("/mini/scripts/cal.mini.fth")
        .then((response) => {
          if (response.ok) {
            return response.text();
          } else {
            throw new Error("Couldnt get file")
          }
        })
        .then((script) => {
          m.runScript(script)
        })

      document.addEventListener("mini.print", (e)=>{
        const str = e.detail
        props.pushLine(str);
      })

      m.repl();

      const startingCmd = ": this-month y/m/d flip to year nip 1cal ;";

      props.pushLine(PROMPT + startingCmd)
      document.dispatchEvent(new CustomEvent("mini.read", {
        detail: startingCmd,
      }));
    }
  });

  return (
    <div
      class="bg-[#202020] focus:bg-[#000010] text-gray-400 focus:text-white text-xs flex flex-col-reverse overflow-scroll"
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
            props.pushLine(PROMPT + c);
            const ev = new CustomEvent("mini.read", {
              detail: c,
            });
            document.dispatchEvent(ev);
            setCmd("");
          }
        } else if (ev.key === "Backspace") {
          setCmd((p)=>p.slice(0, p.length-1));
        } else if (ev.key.length === 1) {
          setCmd((p)=>p+ev.key);
        }
      }}
    >
      <pre class="h-[1lh] shrink-0">
        {PROMPT + cmd()}
      </pre>
      <Index each={props.history().toReversed()}>
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

const RunButton = (props) => {
  return (
    <button
      class="bg-[#606060] hover:bg-[#101010] hover:cursor-pointer"
      on:click={()=>{
        props.pushLine(PROMPT + props.cmd)
        document.dispatchEvent(new CustomEvent("mini.read", {
          detail: props.cmd,
        }));
      }}
    >
      {props.cmd}
    </button>
  );
}

const App: Component = () => {
  const [mini] = createResource(fetchMini);
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

  return (
    <div class="w-screen h-screen flex flex-col font-mono bg-[#303030] text-white items-center">
      <TitleBar />
      <div class="flex flex-row gap-20 items-center grow min-h-0">
        <TerminalComponent mini={mini()} history={history} pushLine={pushLine} />
        <div>
          <div>
            Click on the terminal to activate it
          </div>
          <div>
            Enter commands and press enter!
          </div>
          <div>
            (you can also just click on the commands below)
          </div>
          <div>
            <RunButton cmd="ashy" mini={mini()} pushLine={pushLine} />{" "}
            <RunButton cmd="words cr" mini={mini()} pushLine={pushLine} />{" "}
            <RunButton cmd="0 256 dump" mini={mini()} pushLine={pushLine} />{" "}
            <RunButton cmd="2026 to year 1 3cal" mini={mini()} pushLine={pushLine} />{" "}
          </div>
          <div>
            <RunButton cmd="this-month" mini={mini()} pushLine={pushLine} />
          </div>
        </div>
      </div>
    </div>
  );
};

export default App;
