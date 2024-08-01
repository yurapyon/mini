import { Memory } from "./Memory";
import { Bounds } from "./Range";
import { Register } from "./Register";

export class Stack {
  memory: Memory;
  top: Register;
  bounds: Bounds;

  constructor(memory: Memory, top_offset: number, bounds: Bounds) {
    this.memory = memory;
    this.top = new Register(this.memory, top_offset);
    this.bounds = bounds;
  }
}
