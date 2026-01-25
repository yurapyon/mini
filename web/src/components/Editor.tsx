import { onMount, createSignal } from "solid-js";

import * as monaco from "monaco-editor";

import editorWorker from 'monaco-editor/esm/vs/editor/editor.worker?worker';

import { useMiniContext } from "../components/providers/MiniProvider";

// ===

const introScript = `\\ ===
\\
\\ This is the web demo for mini, a 16bit forth
\\
\\ You can edit the text here and run it as mini code with the buttons above.
\\ You can also click on the commands below the editor
\\
\\ Theres a terminal you can activate by clicking on it.
\\ Just type commands and press enter!
\\
\\ This site is a work in progress, please see the mini repo for more info
\\
\\ Notes:
\\ - 'reset then run' will reinitialize the forth runtime before running the script
\\ - the command buttons under the editor may stop working after a reset
\\
\\ ===

: wahoo s" wahoo" type cr ;

wahoo
`;

window.MonacoEnvironment = {
    getWorker(_workerId: any, _label: string) {
        return new editorWorker();
    }
};

export const Editor = () => {
  const mini = useMiniContext();

  const [model, setModel] = createSignal(null);
  const [editor, setEditor] = createSignal(null);

  let container;

  onMount(()=>{
    // monaco.languages.register({ id: "typescript" })

    const model = monaco.editor.createModel(
      introScript,
      // monaco.Uri.parse("file:///main.ts"),
    );

    model.getOptions().indentSize = 2;

    const editor = monaco.editor.create(container, {
      model,
      theme: 'vs-dark',
      minimap: {
        enabled: false,
      },
    });

    setModel(model)
    setEditor(editor)
  });

  const runScript = () => {
    const script = model().getValue()
    document.dispatchEvent(new CustomEvent("mini.read", {
      detail: script,
    }));
  }

  return (
    <div class="flex flex-col min-h-0 grow w-full">
      <div class="flex flex-row gap-[1ch]">
        <button
          class="bg-[#505050] hover:bg-[#101010] hover:cursor-pointer px-[0.5ch] whitespace-nowrap basis-1/2"
          on:click={() => {
            mini().reset();
            runScript();
          }}
        >
          reset forth then run script
        </button>
        <button
          class="bg-[#505050] hover:bg-[#101010] hover:cursor-pointer px-[0.5ch] whitespace-nowrap basis-1/2"
          on:click={() => {
            runScript();
          }}
        >
          just run script
        </button>
      </div>
      <div
        ref={container}
        class="min-h-0 grow"
      />
    </div>
  );
}
