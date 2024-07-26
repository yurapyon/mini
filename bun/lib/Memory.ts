interface Memory {
  _data: ArrayBuffer;
  _bytes: Uint8Array;
  _cells: Uint16Array;
}

export namespace Memory {
  export const create = (size: number): Memory => {
    const arrayBuffer = new ArrayBuffer(size);
    return {
      _data: arrayBuffer,
      _bytes: new Uint8Array(arrayBuffer),
      _cells: new Uint16Array(arrayBuffer),
    };
  };

  export const getByteAt = (memory: Memory, addr: number) => {
    // TODO check out of bounds
    return memory._bytes[addr];
  };

  export const getByteAlignedCellAt = (memory: Memory, addr: number) => {
    // TODO check out of bounds
    const lowByte = memory._bytes[addr];
    const highByte = memory._bytes[addr + 1];
    return (highByte << 8) | lowByte;
  };

  export const getCellAt = (memory: Memory, addr: number) => {
    // TODO check out of bounds
    if (addr % 2 !== 0) {
      throw "alignment error";
    }
    return memory._cells[addr / 2];
  };

  export const setCellAt = (memory: Memory, addr: number, value: number) => {
    // TODO check out of bounds
    if (addr % 2 !== 0) {
      throw "alignment error";
    }
    return (memory._cells[addr / 2] = value);
  };

  export const cellAt = (memory: Memory, addr: number, value?: number) => {
    if (value) {
      return setCellAt(memory, addr, value);
    } else {
      return getCellAt(memory, addr);
    }
  };
}
