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
  ['] branch ,
  swap
  here@ - ,
  over here@ -
  swap ! ; immediate

: unwrap 0= if panic then ;
: >cfa >terminator 1+ ;
: find-word find unwrap unwrap ;

: [compile]
  word find-word >cfa absjump
  ; immediate

here @ ##.s

: binary 2 base ! ;
: decimal 10 base ! ;
: hex 16 base ! ;




: thing if 0 else 1 then ;

1 thing ##.s

bye



: 2dup over over ;
: 2drop drop drop ;
: 2over 3 pick 3 pick ;
: 3dup 2 pick 2 pick 2 pick ;
: 3drop drop 2drop ;
: flip swap rot ;

: cells 2 * ;


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
