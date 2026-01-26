import { createResource, createEffect, createSignal, Index } from "solid-js";
import type { Component } from 'solid-js';
import { TitleBar } from "./components/TitleBar";
import { SystemComponent } from "./components/SystemComponent";
import { Documentation } from "./components/documentation/Documentation";
import { MiniProvider, useMiniContext } from "./components/providers/MiniProvider";
import { Editor } from "./components/Editor";

import { Shell } from "./lib/shell";

const shell = new Shell();

const PROMPT = "mini> ";

import { Terminal } from "./lib/console";

const terminal = new Terminal();

// TODO
//   technically you should pause and resume for all async calls from forth
//   figure out a nice way to do this

const TerminalComponent = (props) => {
  const mini = useMiniContext();

  const [history, setHistory] = createSignal([], {
    equals: false
  });

  shell.onUpdate = () => {
    setHistory(shell.history)
  }

  const [cmd, setCmd] = createSignal("");

  createEffect(async ()=>{
    const m = mini();
    if (m) {
      m.setEmitCallback((ch)=>{
        shell.putc(ch)
      });

      m.addExternal("clear", ()=>{
        shell.clearHistory()
      })
    }
  });

  return (
    <div
      class="group bg-[#181818] focus:bg-[#000010] text-[#b0b0b0] focus:text-white text-xs flex flex-col-reverse overflow-y-auto min-h-0 grow w-full"
      style={{
        // width: terminal.width + "ch",
        height: "10lh",
      }}
      tabIndex="0"
      on:keydown={(ev)=>{
        ev.preventDefault();
        const c = cmd();
        if (ev.key === "Enter") {
          if (c.length > 0) {
            shell.pushLine({
              isUser: true,
              text: c,
            });
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
      <Index each={history().toReversed()}>
        {(line)=>{
          return (
            <pre class="text-wrap">
              {line().isUser && PROMPT}{line().text}
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
      class="bg-[#505050] hover:bg-[#101010] hover:cursor-pointer px-[0.5ch] whitespace-nowrap"
      on:click={()=>{
        shell.pushLine({
          isUser: true,
          text: props.cmd,
        });
        document.dispatchEvent(new CustomEvent("mini.read", {
          detail: props.cmd,
        }));
      }}
    >
      {props.cmd}
    </button>
  );
}

const Tutorial = () => {
  return (
    <div class="flex flex-row gap-x-[1ch] flex-wrap text-sm p-2">
      <div class="flex flex-row gap-[1ch]">
        terminal:
        <RunButton cmd="clear" />
      </div>
      <div class="flex flex-row gap-[1ch]">
        printing:
        <RunButton cmd="ashy" />
        <RunButton cmd="words cr" />
        <RunButton cmd="0 256 dump" />
      </div>
      <div class="flex flex-row gap-[1ch]">
        date/time:
        <RunButton cmd="this-month 1cal" />
        <RunButton cmd="2000 12cal" />
        <RunButton cmd="time .time24 cr" />
      </div>
      <div class="flex flex-row gap-[1ch]">
        graphics:
        <RunButton cmd="random-color >bg" />
        <RunButton cmd="random-point sprite >s.pos" />
      </div>
    </div>
  );
}

const App: Component = () => {
  return (
    <MiniProvider>
      <div class="w-screen h-screen flex flex-col font-mono bg-[#303030] text-white">
        <TitleBar />
        <div class="flex flex-row grow min-h-0 text-sm">
          <div class="flex flex-col basis-1/2">
            <Editor />
            <Tutorial />
          </div>
          <div class="flex flex-col grow min-w-0 items-center basis-1/2">
            <SystemComponent mini={mini()} />
            <TerminalComponent />
          </div>
        </div>
      </div>
    </MiniProvider>
  );
};

export default App;
