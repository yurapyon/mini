# : mini ;
a 16bit Forth for desktop and web  
[try it out online](https://mini-nrlx.onrender.com/)  

### goals
- clear, simple and obvious
  - don't sacrifice readibility for performance
- evolution of a classic
  - "writing a forth" is more important than "designing a modern language"

### see
- `/repo-overview` for repo info
- `/mini-specs` for language/vm specs
- `src/examples` for code samples  

### features
- overall
  - clean, self-documenting codebase (hopefully)
  - well-defined, obvious memory layout
  - self-hosting with metacompiler
    - parser and interpreter written in forth
    - boots from a system image
      - included system image is pretty small, around 2.5kb
  - automatic tailcall optimization
  - cross-platform on desktop and web
- language
  - covers most of the ANSI Forth 'Core' word set
  - vocabularies, search order
  - string escapes, including multiline strings
  - easy-to-use FFI, currently builds in:
    - OS access
    - 32-bit floats
    - dynamic memory
    - random number generation
- virtual PC
  - based off of the PC-98 computer
    - pixel buffer
    - character buffer
  - mouse/keyboard callbacks
  - separate threads for graphics and interpreter
  - gamepad support

### roadmap
- in progress
  - webassembly target
- planned
  - io
    - audio
  - cross-compiler for avr/pic
- maybe

### building
you need:
  - mac OS
  - zig
  - glfw

### setup:
mac OS, using homebrew:
- `$ brew install zig glfw`
- `$ zig build`
- `$ ./shell/run.sh`

### license
MIT
