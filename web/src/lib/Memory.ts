export class Memory {
  _memory: ArrayBuffer;
  _cells: Uint16Array;
  _bytes: Uint8Array;

  constructor(size: number) {
    this._memory = new ArrayBuffer(size);
    this._cells = new Uint16Array(this._memory);
    this._bytes = new Uint8Array(this._memory);
  }

  assertAccess(addr: number) {
    if (addr >= this._cells.length) {
      throw new Error("out of bounds");
    }
  }

  fetch(addr: number) {
    this.assertAccess(addr);
    return this._cells[addr];
  }

  store(addr: number, value: number) {
    this.assertAccess(addr);
    this._cells[addr] = value;
  }

  storeAdd(addr: number, value: number) {
    this.assertAccess(addr);
    this._cells[addr] += value;
  }

  checkCellAccess(addr: number) {
    if (addr % 2 !== 0) {
      throw new Error("alignment");
    }
    const cell_addr = addr / 2;
    this.assertAccess(cell_addr);
    return cell_addr;
  }

  fetchCell(addr: number) {
    const cell_addr = this.checkCellAccess(addr);
    return this._cells[cell_addr];
  }

  storeCell(addr: number, value: number) {
    const cell_addr = this.checkCellAccess(addr);
    this._cells[cell_addr] = value;
  }

  storeAddCell(addr: number, value: number) {
    const cell_addr = this.checkCellAccess(addr);
    this._cells[cell_addr] += value;
  }
}
