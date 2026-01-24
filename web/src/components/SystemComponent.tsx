import { onMount, createSignal, createEffect } from "solid-js";
import { Application, Graphics } from "pixi.js";

import { useMiniContext } from "./providers/MiniProvider";

const loadSystem = async (container) => {
  const app = new Application();

  await app.init({
    background: '#1099bb',
    resizeTo: container
  });

  container.appendChild(app.canvas);

  const sprites = [];

  const createSprite = () => {
    const sprite = new Graphics();
    sprite.rect(0, 0, 100, 100).fill({ color: "white" })

    app.stage.addChild(sprite);

    const idx = sprites.len;
    sprites.push(sprite);
    return idx
  };

  const getSprite = (idx) => {
    return sprites[idx];
  }

  return {
    app,
    createSprite,
    getSprite
  };
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
        a.app.renderer.background.color = "#" + str;
      })
      m.addExternal("random", ()=>{
        const value = Math.floor(Math.random() * 2**16);
        m.kernel.push(value);
      })
      m.addExternal("s.new", ()=>{
        const idx = a.createSprite();
        m.kernel.push(idx);
      })
      m.addExternal("s.delete", ()=>{
        const idx = m.kernel.pop();
        // TODO
      })
      m.addExternal(">s.pos", ()=>{
        const idx = m.kernel.pop();
        const y = m.kernel.pop();
        const x = m.kernel.pop();
        const sprite = a.getSprite(idx);
        if (!!sprite) {
          sprite.position.x = x;
          sprite.position.y = y;
        }
      })

      document.dispatchEvent(new CustomEvent("mini.read", {
        detail: ": random-color random random random ;"
      }));
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
