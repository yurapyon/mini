const PROMPT = "mini> ";

export interface Line {
  isUser: boolean;
  text: string;
}

export class Shell {
  history: Line[];
  onUpdate: () => void;
  consoleBuffer: [];

  constructor() {
    this.history = [];
    this.onUpdate = () => {};
    this.consoleBuffer = [];
  }

  pushLine(line) {
    if (this.history.length >= 300) {
      this.history.shift();
    }
    this.history.push(line);
    this.onUpdate();
  }

  clearHistory() {
    this.history = [];
    this.onUpdate();
  }

  putc(char) {
    if (char === 10) {
      const str = String.fromCharCode(...this.consoleBuffer);
      this.pushLine({
        isUser: false,
        text: str,
      });
      this.onUpdate();
      this.consoleBuffer.length = 0;
    } else {
      this.consoleBuffer.push(char);
    }
  }
}
