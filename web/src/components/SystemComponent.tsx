import { onMount, createSignal, createEffect } from "solid-js";
import { Application, Graphics } from "pixi.js";

import { useMiniContext } from "./providers/MiniProvider";
import { usePixiContext } from "./providers/PixiProvider";

const Screen = () => {
  const app = usePixiContext();

  let container;

  createEffect(() => {
    const a = app();
    if (!!a && !!container) {
      container.appendChild(a.app.canvas);
    }
  });

  return <div ref={container} class="w-full aspect-[16/10] max-w-[640px]" />;
};

export const SystemComponent = (props) => {
  return (
    <div class="w-full flex flex-row justify-center p-2 bg-black">
      <Screen />
    </div>
  );
};
