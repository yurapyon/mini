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

: mark-offset, here@ 0 c, ;
: backward-offset here@ - ;
: store-offset here@ over - swap c! ;

: if   ['] branch0 c, mark-offset, ; immediate
: else ['] branch  c, mark-offset, swap store-offset ; immediate
: then store-offset ; immediate

: begin here@ ; immediate
: until ['] branch0 c, backward-offset c, ; immediate
: again ['] branch  c, backward-offset c, ; immediate

: while  [compile] if ; immediate
: repeat swap [compile] again [compile] then ; immediate

: \ begin next-char 10 = until ; immediate

\ we have comments now wahoo

: bytes!   tuck c! 1+ c! ;
: bytesLE! swap cell>bytes rot bytes! ;
: bytesBE! swap cell>bytes swap rot bytes! ;

: absjump! swap mkabsjump swap bytesBE! ;

: binary 2 base ! ;
: decimal 10 base ! ;
: hex 16 base ! ;

: :noname 0 0 define here@ ] ;

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

: -aligned 2dup mod ?dup if - + else drop then ;
: -align   here@ swap -aligned here! ;
: aligned  cell -aligned ;
: align    cell -align ;

: >cfa >terminator 1+ ;
: literal ['] lit c, bytesLE, ; immediate

: create
  word define align
  here@ 6 +
  [compile] literal ['] exit c, 0 c, ['] exit c, ;

: >body           aligned 6 + ;
: >does-register  >body 3 - ;
: redirect-latest latest @ >cfa >does-register absjump! ;

: does>
  \ address of code that follows the does>
  here@ 6 +
  [compile] literal ['] redirect-latest absjump, ['] exit c,
  ; immediate

: constant
  create ,
  does> @ ;

: recurse
  \ compiles the 'currently being defined' xt as a tailcall
  \ latest @ >cfa tailcall
  ; immediate

15 constant x
x ' x >body ##.s drop drop

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

