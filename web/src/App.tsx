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
      m.addExternal("h/m/s", ()=>{
        const date    = new Date();
        const hours   = date.getHours();
        const minutes = date.getMinutes();
        const seconds = date.getSeconds();
        m.kernel.push(hours)
        m.kernel.push(minutes)
        m.kernel.push(seconds)
      })
      m.addExternal("clear", ()=>{
        props.clearHistory()
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

      m.runScript(`
        : 24>12     12 mod dup 0= if drop 12 then ;
        : time      h/m/s flip 24 mod flip ;
        : 00:#      # # drop ':' hold ;
        : .time24   <# 00:# 00:# # # #> type ;
        : .time12hm drop <# 00:# 24>12 # # #> type ;
      `);

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
      class="group bg-[#202020] focus:bg-[#000010] text-gray-400 focus:text-white text-xs flex flex-col-reverse overflow-scroll"
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
      <pre class="h-[1lh] shrink-0 flex flex-row">
        <pre>
          {PROMPT + cmd()}
        </pre>
        <div class="w-[1ch] shrink-0 bg-gray-400 group-focus:bg-white group-focus:animate-(--animate-blink) h-full"/>
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
      class="bg-[#505050] hover:bg-[#101010] hover:cursor-pointer px-[0.5ch]"
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

  const clearHistory = () => {
    setHistory([]);
  };

  return (
    <div class="w-screen h-screen flex flex-col font-mono bg-[#303030] text-white items-center">
      <TitleBar />
      <div class="flex flex-row gap-20 items-center grow min-h-0">
        <TerminalComponent
          mini={mini()}
          history={history}
          pushLine={pushLine}
          clearHistory={clearHistory}
        />
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
          <div class="flex flex-row flex-wrap gap-x-[1ch] max-w-lg">
            <RunButton cmd="ashy" mini={mini()} pushLine={pushLine} />
            <RunButton cmd="words cr" mini={mini()} pushLine={pushLine} />
            <RunButton cmd="0 256 dump" mini={mini()} pushLine={pushLine} />
            <RunButton cmd="2026 to year 1 3cal" mini={mini()} pushLine={pushLine} />
            <RunButton cmd="this-month" mini={mini()} pushLine={pushLine} />
            <RunButton cmd="time .time24 cr" mini={mini()} pushLine={pushLine} />
            <RunButton cmd="clear" mini={mini()} pushLine={pushLine} />
          </div>
        </div>
      </div>
    </div>
  );
};

export default App;
