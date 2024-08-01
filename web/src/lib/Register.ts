import { Memory } from "./Memory";
import { VM } from "./VM";

export class Register {
  memory: Memory;
  offset: number;

  constructor(memory: Memory, offset: number) {
    this.memory = memory;
    this.offset = offset;
  }

  store(value: number) {
    this.memory.storeCell(this.offset, value);
  }

  fetch() {
    return this.memory.fetchCell(this.offset);
  }

  storeAdd(value: number) {
    this.memory.storeAddCell(this.offset, value);
  }

  comma(value: number) {
    const addr = this.fetch();
    this.memory.storeCell(addr, value);
    this.storeAdd(2);
  }

  storeC(value: number) {
    this.memory.store(this.offset, value);
  }

  fetchC() {
    return this.memory.fetch(this.offset);
  }

  storeAddC(value: number) {
    return this.memory.storeAdd(this.offset, value);
  }

  commaC(value: number) {
    const addr = this.fetch();
    this.memory.store(addr, value);
    this.storeAdd(1);
  }
}
