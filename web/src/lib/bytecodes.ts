import { MiniVM } from "./VM";

export type BytecodeCallback = (vm: MiniVM) => void;

interface Bytecode {
  name: string;
  interpret: BytecodeCallback;
  compile: BytecodeCallback;
  execute: BytecodeCallback;
}

const nop: BytecodeCallback = () => {};

const compileSelf: BytecodeCallback = (vm: MiniVM) => {
  // TODO
};

const nopCallbacks = () => {
  return {
    interpret: nop,
    compile: nop,
    execute: nop,
  };
};

const basicCallbacks = (callback: BytecodeCallback) => {
  return {
    interpret: callback,
    compile: compileSelf,
    execute: callback,
  };
};

export const bytecodes: Bytecode[] = [
  {
    name: "panic",
    ...basicCallbacks(() => {
      throw Error("panic");
    }),
  },
];
