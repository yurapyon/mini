word xorc!     define ] tuck c@ xor swap c! [ ' exit c,
word immediate define ] 0b01000000 latest @ >terminator xorc! [ ' exit c,
word hide      define ] 0b00100000 swap >terminator xorc! [ ' exit c,
word :         define ] word define latest @ hide ] [ ' exit c,
word ;         define ] ['] exit c, latest @ hide [ ' [ c, ' exit c, immediate

: begin
  here@
  ; immediate

: until
  ['] branch0 c,
  here@ - c,
  ; immediate

: \
  begin
    next-char 10 =
  until ; immediate

: if
  \ on 0, you want to branch to the 'then' or the 'else'
  \ compile a branch0 without an offset
  \   but push the addr to write the calculated offset
  ['] branch0 c,
  here@ 0 c, ; immediate

: else
  \ finish off the body of the 'if (true)' block
  \   with a branch that skips to the 'then'
  \ ( branch-offset-addr )
  ['] branch c,
  here@ 0 c,
  swap
  \ then update the if's 'branch0' to jump here if it branches
  here@ over -
  swap c! ; immediate

: then
  \ ( branch-offset-addr )
  here@ over -
  swap c! ; immediate

\ ===

\ TODO document these things
: again
  ['] branch c,
  here@ - c, ; immediate

: while
  ['] branch0 c,
  here@ 0 c,
  ; immediate

: repeat
  ['] branch c,
  swap
  here@ - c,
  over here@ -
  swap ! ; immediate

\ TODO unwrap isnt super great
: unwrap 0= if panic then ;

: >cfa >terminator 1+ ;

: find-word find unwrap unwrap ;

: bytes, cell>bytes swap c, c, ;
: bytesBE, cell>bytes c, c, ;
: bytes!
  \ ( value addr )
  over 8 rshift over 1+
  \ ( low addr high addr+1 )
  c! c! ;
: bytesBE!
  over 8 rshift over c! 1+ c! ;

: mkabsjump 0x8000 or ;
: absjump, mkabsjump bytesBE, ;
: absjump! swap mkabsjump swap bytesBE! ;

: [compile]
  word find-word >cfa absjump,
  ; immediate

: binary 2 base ! ;
: decimal 10 base ! ;
: hex 16 base ! ;

: :noname 0 0 define here@ ] ;

: recurse
  \ compiles the 'currently being defined' xt as a tailcall
  \ latest @ >cfa tailcall
  ; immediate

: 2dup over over ;
: 2drop drop drop ;
: 2over 3 pick 3 pick ;
: 3dup 2 pick 2 pick 2 pick ;
: 3drop drop 2drop ;

: cell 2 ;
: cells cell * ;

: u/ u/mod nip ;
: umod u/mod drop ;
: / /mod nip ;
: mod /mod drop ;

: aligned-to
  2dup mod
  ?dup if - + else drop then ;

: align-to
  here@ swap aligned-to here! ;

: aligned cell aligned-to ;

: align cell align-to ;

: create
  word define align
  ['] lit c, here@ 5 + bytes, ['] exit c, 0 c, ['] exit c, ;

: >body aligned 6 + ;
: >does-register >body 3 - ;
: redirect-latest latest @ >cfa >does-register absjump! ;

: does>
  \ address of code that follows the does>
  here@ 6 +
  ['] lit c, bytes, ['] redirect-latest absjump,
  ['] exit c,
  ; immediate

: constant
  create ,
  does> @ ;



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

10 constant xxx
##.s
xxx
##.s

bye

