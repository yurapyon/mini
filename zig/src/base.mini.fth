word xorc!     define ] tuck c@ xor swap c! exit [
word immediate define ] 0b01000000 latest @ >terminator xorc! exit [
word hide      define ] 0b00100000 swap >terminator xorc! exit [
word :         define ] word define latest @ hide ] exit [
word ;         define ' exit litc ] c, latest @ hide [ ' [ c, ] exit [ immediate

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

\ we have comments now wahoo

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

\ TODO test this
: [compile]
  \ TODO this needs the absjump PR
  \ word find-word >cfa absjump
  ; immediate

: binary 2 base ! ;
: decimal 10 base ! ;
: hex 16 base ! ;

: :noname 0 0 define here @ ] ;

: recurse
  \ compiles the 'currently being defined' xt as a tailcall
  \ latest @ >cfa tailcall
  ; immediate

: 2dup over over ;
: 2drop drop drop ;
\ todo test these
: 2over 3 pick 3 pick ;
: 3dup 2 pick 2 pick 2 pick ;
: 3drop drop 2drop ;

: cells 2 * ;

bye

\ should this file have to end with 'bye' or 'quit' ?

\ including files needs an interpreter
\ unless...
\ including files can be done with devices

\ these are useful but you need 'create'

: +field ( start this-size "name" -- end )
  over + swap
  create ,
  does> @ + ;

: field ( start this-size "name" -- end-aligned )
  over aligned   ( start this-size aligned-start )
  flip drop      ( aligned-start this-size )
  +field ;

\ TODO this should be [compile] +field
: cfield +field ;

: ffield ( start this-size "name" -- end-aligned )
  over faligned   ( start this-size aligned-start )
  flip drop       ( aligned-start this-size )
  +field ;

: enum ( value "name" -- value+1 )
  dup constant 1+ ;

\ todo use lshift
: flag ( value "name" -- value<<1 )
  dup constant 2* ;

\ ===

:noname
  1 2 3 ##.s
  ;

execute

\ : create
  \ word define
  \ here@ 4 + lit
  \ ['] exit c, ;

here@
\ create something
here@
##.s

bye

: loop
  0
  begin
    ##.s
    1+
    dup 10 =
  until
  drop
  ;




loop


bye
