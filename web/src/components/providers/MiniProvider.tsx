import { createContext, createResource, useContext } from "solid-js";

import { fetchMini } from "../../lib/mini";

export const MiniContext = createContext();

export const MiniProvider = (props) => {
  const [mini, {mutate}] = createResource(fetchMini);

  /*
  const reset = () => {
    mini().reset();
    mutate(m => ({...m}));
  }

  const val = () => {
    const m = mini()
    if (!!m) {
      return { ...m, reset };
    }
  }
  */

  return (
    <MiniContext.Provider value={mini}>
      {props.children}
    </MiniContext.Provider>
  )
};

export const useMiniContext = () => {
  return useContext(MiniContext);
}
