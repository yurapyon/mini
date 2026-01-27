import {
  createContext,
  createResource,
  useContext,
  createEffect,
} from "solid-js";
import { usePixiContext } from "./PixiProvider";
import { useShellContext } from "./ShellProvider";
import { fetchMini } from "../../lib/mini";

export const MiniContext = createContext();

export const MiniProvider = (props) => {
  const pixi = usePixiContext();
  const shell = useShellContext();

  const pixiAndShell = () => {
    if (!!pixi() && !!shell) {
      return {
        pixi: pixi(),
        shell,
      };
    } else {
      return undefined;
    }
  };

  const [mini] = createResource(pixiAndShell, fetchMini);

  return (
    <MiniContext.Provider value={mini}>{props.children}</MiniContext.Provider>
  );
};

export const useMiniContext = () => {
  return useContext(MiniContext);
};
