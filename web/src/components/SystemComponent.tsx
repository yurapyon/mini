import { onMount, createSignal, createEffect } from "solid-js";
import { Application } from "pixi.js";

import { useMiniContext } from "./providers/MiniProvider";

const loadSystem = async (container) => {
  const app = new Application();

  await app.init({
    background: '#1099bb',
    resizeTo: container
  });

  container.appendChild(app.canvas);

  return app;
};

const Screen = () => {
  const [app, setApp] = createSignal(null);
  const mini = useMiniContext();

  let container;

  onMount(() => {
    loadSystem(container).then(setApp)
  });

  createEffect(()=>{
    const m = mini();
    const a = app();
    if (m && !!a) {
      m.addExternal(">bg", ()=>{
        const r = m.kernel.pop() % 2**8;
        const g = m.kernel.pop() % 2**8;
        const b = m.kernel.pop() % 2**8;
        const str = [r,g,b].map((v)=>v.toString(16).padStart(2, '0')).join("")
        a.renderer.background.color = "#" + str;
      })
      m.addExternal("random", ()=>{
        const value = Math.floor(Math.random() * 2**16);
        m.kernel.push(value);
      })
    }
  });

  return (
    <div
      ref={container}
      class="w-full aspect-[16/10] max-w-[640px]"
    />
  );
}

export const SystemComponent = (props) => {
  return (
    <div class="w-full flex flex-row justify-center">
      <Screen />
    </div>
  );
};
