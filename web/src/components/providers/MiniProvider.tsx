import { createContext, createResource, useContext } from "solid-js";

import { fetchMini } from "../../lib/mini";

export const MiniContext = createContext();

export const MiniProvider = (props) => {
  const [mini] = createResource(fetchMini);

  return (
    <MiniContext.Provider value={mini}>
      {props.children}
    </MiniContext.Provider>
  )
};

export const useMiniContext = () => {
  return useContext(MiniContext);
}
