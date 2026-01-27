import {
  createContext,
  createResource,
  useContext,
  createEffect,
} from "solid-js";
import { Shell } from "../../lib/shell";

export const ShellContext = createContext();

export const ShellProvider = (props) => {
  const shell = new Shell();

  return (
    <ShellContext.Provider value={shell}>
      {props.children}
    </ShellContext.Provider>
  );
};

export const useShellContext = () => {
  return useContext(ShellContext);
};
