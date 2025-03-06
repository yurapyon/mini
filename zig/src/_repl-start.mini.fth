s" mini" type cr

\ todo reset blocks vocab
0 value f0 0 value c0 0 value u0
: empty f0 forth-latest ! c0 compiler-latest ! u0 h ! ;
forth-latest @ to f0 compiler-latest @ to c0 h @ to u0

[defined] empty-buffers [if] empty-buffers [then]

-6 to hour-adj

forth definitions

