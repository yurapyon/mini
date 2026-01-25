import { onMount, createSignal } from "solid-js";
import * as monaco from "monaco-editor";

import editorWorker from 'monaco-editor/esm/vs/editor/editor.worker?worker';

window.MonacoEnvironment = {
    getWorker(_workerId: any, _label: string) {
        return new editorWorker();
    }
};

export const Editor = () => {
  const [model, setModel] = createSignal(null);
  const [editor, setEditor] = createSignal(null);

  let container;

  onMount(()=>{
    // monaco.languages.register({ id: "typescript" })

    const model = monaco.editor.createModel(
      "",
      // "typescript",
      // monaco.Uri.parse("file:///main.ts"),
    );

    model.getOptions().indentSize = 2;

    const editor = monaco.editor.create(container, {
      model,
      // language: 'typescript',
      theme: 'vs-dark',
      minimap: {
        enabled: false,
      },
    });

    setModel(model)
    setEditor(editor)

    document.dispatchEvent(new CustomEvent("mini.read", {
      detail: `
        \\ vocabulary script
      `,
    }));
  });

  return (
    <div class="flex flex-col min-h-0 grow w-full">
      <div
        ref={container}
        // id="asdf"
        // class="w-full aspect-[16/10] max-w-[640px]"
        class="w-[80ch] min-h-0 grow"
      />
      <button
        class="bg-[#505050] hover:bg-[#101010] hover:cursor-pointer px-[0.5ch] whitespace-nowrap"
        on:click={()=>{
          const cmd = model().getValue()
          // TODO
          // script needs to reset current vocabulary too
          document.dispatchEvent(new CustomEvent("mini.read", {
            detail: `
              \\ also script definitions
              ${cmd}
              \\ previous definitions
              \\ also script
            `,
          }));
        }}
      >
        run script
      </button>
    </div>
  );
}
