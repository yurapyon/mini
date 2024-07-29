word xorc!     define ] tuck c@ xor swap c! [ ' exit c,
word immediate define ] 0b01000000 latest @ >terminator xorc! [ ' exit c,
word hide      define ] 0b00100000 swap >terminator xorc! [ ' exit c,
word :         define ] word define latest @ hide ] [ ' exit c,
word ;         define ] ['] exit c, latest @ hide [ ' [ c, ' exit c, immediate

: bytes,   c, c, ;
: bytesLE, cell>bytes bytes, ;
: bytesBE, cell>bytes swap bytes, ;

: mkabsjump 0x8000 or ;
: absjump, mkabsjump bytesBE, ;

: [compile] ' absjump, ; immediate

: must-go,  ['] branch  c, here @ ;
: maybe-go, ['] branch0 c, here @ ;
: idk,      0 c, ;
: to-here!  here @ over - swap c! ;
: back,     - c, ;

: if   maybe-go, idk, ; immediate
: else must-go,  idk, swap to-here! ; immediate
: then to-here! ; immediate

: begin here @ ; immediate
: until maybe-go, back, ; immediate
: again must-go,  back, ; immediate

: while  [compile] if ; immediate
: repeat swap [compile] again [compile] then ; immediate

: \ begin next-char 10 = until ; immediate

\ we have comments now wahoo

: bytes!   tuck c! 1+ c! ;
: bytesLE! swap cell>bytes rot bytes! ;
: bytesBE! swap cell>bytes swap rot bytes! ;

: absjump! swap mkabsjump swap bytesBE! ;

: something, ['] lit  c, here @ 0 c, 0 c, ;
: smthng,    ['] litc c, here @ 0 c, ;
: this       here @ swap ;
: this!      this bytesLE! ;
: ths!       this c! ;
: how-far    this - ;

: binary 2 base ! ;
: decimal 10 base ! ;
: hex 16 base ! ;

: :noname 0 0 define here @ ] ;

: 2dup over over ;
: 2drop drop drop ;
: 2over 3 pick 3 pick ;
: 3dup 2 pick 2 pick 2 pick ;
: 3drop drop 2drop ;

: cell 2 ;
: cells cell * ;

: u/   u/mod nip ;
: umod u/mod drop ;
: /    /mod nip ;
: mod  /mod drop ;

: aligned dup cell mod + ;
: align   here @ aligned here ! ;

: >cfa >terminator 1+ ;

\ ===

: >body       aligned 6 + ;
: >does       >body 3 - ;
: do-nothing, ['] exit c, 0 c, ;
: do-this!    latest @ >cfa >does absjump! ;

: create
  word define align
  something, do-nothing, ['] exit c, this! ;

: does>
  state @ if
    something, ['] do-this! absjump, ['] exit c, this!
  else
    here @ do-this!
    latest @ hide
    ]
  then ; immediate

\ ===

: constant create , does> @ ;

: recurse
  \ compiles the 'currently being defined' xt as a tailcall
  \ latest @ >cfa tailcall
  ; immediate

: char word drop c@ ;
: [char] ['] litc c, char c, ; immediate

: "? [char] " = ;

: string,
  next-char drop
  begin next-char dup "? 0= while c, repeat
  drop ;

\ NOTE
\ go... can only be a byte, thus strings can only be 255 chars
\   to make the jump longer you have to compile a tailcall
\ here @ do-nothing,
\ tailcall!
: s"
  something, smthng, must-go, idk, >r
  swap this!
  here @ string, this - swap c!
  r> to-here!
  ; immediate

: stringy s" hello" ;

stringy ##.s
stringy ##type ##cr

bye

: +field
  over + swap
  create ,
  does> @ + ;

: field
  over aligned
  flip drop
  +field ;

: enum
  dup constant 1+ ;

: flag
  dup constant 1 lshift ;

\ TODO values, variables
\ TODO strings

\ should this file have to end with 'bye' or 'quit' ?

\ including files needs an interpreter
\ unless...
\ including files can be done with devices

bye

