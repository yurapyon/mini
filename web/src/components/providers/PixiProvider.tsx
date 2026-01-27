import { createContext, createResource, useContext } from "solid-js";

import { Application, Graphics } from "pixi.js";

const loadSystem = async () => {
  const app = new Application();

  await app.init({
    background: "#1099bb",
    width: 640,
    height: 400,
  });

  const sprites = [];

  const createSprite = () => {
    const sprite = new Graphics();
    sprite.rect(-40, -40, 80, 80).fill({ color: "white" });

    sprite.position.x = 320;
    sprite.position.y = 200;

    app.stage.addChild(sprite);

    const idx = sprites.length;
    sprites.push(sprite);
    return idx;
  };

  const getSprite = (idx) => {
    return sprites[idx];
  };

  return {
    app,
    createSprite,
    getSprite,
  };
};

export const PixiContext = createContext();

export const PixiProvider = (props) => {
  const [pixi] = createResource(loadSystem);

  return (
    <PixiContext.Provider value={pixi}>{props.children}</PixiContext.Provider>
  );
};

export const usePixiContext = () => {
  return useContext(PixiContext);
};
