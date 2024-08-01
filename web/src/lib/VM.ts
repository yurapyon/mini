import { MAX_VM_MEMORY_SIZE, MEMORY_LAYOUT } from "./constants";
import { Memory } from "./Memory";
import { Stack } from "./Stack";

export class VM {
  memory: Memory;
  data_stack: Stack;
  return_stack: Stack;

  constructor() {
    this.memory = new Memory(MAX_VM_MEMORY_SIZE);
    this.data_stack = new Stack(this.memory, MEMORY_LAYOUT.data_stack_top, {
      start: MEMORY_LAYOUT.data_stack,
      end: MEMORY_LAYOUT.data_stack_end,
    });
    this.return_stack = new Stack(this.memory, MEMORY_LAYOUT.return_stack_top, {
      start: MEMORY_LAYOUT.return_stack,
      end: MEMORY_LAYOUT.return_stack_end,
    });
  }

  interpret(word: string) {}

  lookup() {}
}
