export class Terminal {
  width: number;
  height: number;
  buffer: Array<number>;

  onRedraw: any

  constructor() {
    this.width = 80;
    this.height = 40;

    this.buffer = new Array(this.width * this.height);
    this.buffer.fill(0)
  }

  putXY(ch: number, x: number, y: number) {
    this.buffer[y * this.width + x] = ch;
    // this.onRedraw(x, y, 1, 1);
    console.log("put", ch, x, y);
  }
}
