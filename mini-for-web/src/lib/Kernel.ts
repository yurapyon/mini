type Memory = Uint8Array;
type Cell = Uint16;

class Register {
  memory: Memory,
  offset: number,

  constructor(memory: Memory, offset: number) {
    this.memory = memory;
    this.offset = offset;
  }

  store(value: Cell) {
    this.memory[this.offset] = value;
  }
}

class Stack {
  memory: Memory,
  topPtr: Register,
  stackTopAddr: number,

  constructor(memory: Memory, topPtrAddr: number, stackTopAddr: number) {
    this.memory = memory;
    this.stackTopAddr = stackTopAddr;

    this.topPtr = new Register(this.memory, topPtrAddr);
    this.topPtr.store(this.stackTopAddr);
  }


}
