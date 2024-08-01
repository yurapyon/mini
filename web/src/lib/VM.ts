import { MAX_VM_MEMORY_SIZE, MEMORY_LAYOUT } from "./constants";
import { Memory } from "./Memory";
import { Register } from "./Register";
import { Stack } from "./Stack";

export class MiniVM {
  memory: Memory;
  program_counter: Register;
  data_stack: Stack;
  return_stack: Stack;
  // dictionary
  state: Register;
  base: Register;
  // input source
  // devices

  should_quit: boolean;
  should_bye: boolean;

  constructor() {
    this.memory = new Memory(MAX_VM_MEMORY_SIZE);
    this.program_counter = new Register(
      this.memory,
      MEMORY_LAYOUT.program_counter
    );
    this.data_stack = new Stack(this.memory, MEMORY_LAYOUT.data_stack_top, {
      start: MEMORY_LAYOUT.data_stack,
      end: MEMORY_LAYOUT.data_stack_end,
    });
    this.return_stack = new Stack(this.memory, MEMORY_LAYOUT.return_stack_top, {
      start: MEMORY_LAYOUT.return_stack,
      end: MEMORY_LAYOUT.return_stack_end,
    });
    //
    this.state = new Register(this.memory, MEMORY_LAYOUT.state);
    this.base = new Register(this.memory, MEMORY_LAYOUT.base);
    //
    //

    this.should_quit = false;
    this.should_bye = false;
  }

  interpret(word: string) {}

  lookup() {}
}
