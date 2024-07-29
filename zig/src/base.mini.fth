word xorc!     define ] tuck c@ xor swap c! [ ' exit c,
word immediate define ] 0b01000000 latest @ >terminator xorc! [ ' exit c,
word hide      define ] 0b00100000 swap >terminator xorc! [ ' exit c,
word :         define ] word define latest @ hide ] [ ' exit c,
word ;         define ] ['] exit c, latest @ hide [ ' [ c, ' exit c, immediate

: bytes,   c, c, ;
: >little, cell>bytes bytes, ;
: >big,    cell>bytes swap bytes, ;

: bytes!   tuck c! 1+ c! ;
: >little! >r cell>bytes r> bytes! ;
: >big!    >r cell>bytes swap r> bytes! ;

: mkabsjump 0x8000 or ;
: xt,       mkabsjump >big, ;
: xt!       >r mkabsjump r> >big! ;

: this       here @ swap ;
: how-far    this - ;
: this!      this >little! ;
: over-here! this xt! ;

: idk,       0 c, ;
: idunno,    0 0 bytes, ;
: smthng,    ['] litc c, here @ idk, ;
: something, ['] lit c, here @ idunno, ;

: go-now,       ['] tailcall c, xt, ;
: go-somewhere, ['] tailcall c, here @ idunno, ;

: jump,       ['] branch  c, here @ idk, ;
: jump?,      ['] branch0 c, here @ idk, ;
: right-here! dup how-far swap c! ;
: back!       tuck - swap c! ;

: if   jump?, ; immediate
: else jump, swap right-here! ; immediate
: then right-here! ; immediate

: begin here @ ; immediate
: until jump?, back! ; immediate
: again jump,  back! ; immediate
: while jump?, ; immediate
: repeat swap jump, back! right-here! ; immediate

: char   word drop c@ ;
: [char] ['] litc c, char c, ; immediate

: \ begin next-char 10 = until ; immediate

: is()
  dup [char] ( = if  drop 1 [ ' exit c, ] then
      [char] ) = if      -1 [ ' exit c, ] then
  0 ;

: ( 1 begin next-char is() + dup 0= until drop ; immediate

: :noname 0 0 define here @ ] ;

: 2dup over over ;
: 2drop drop drop ;
: 2over 3 pick 3 pick ;
: 3dup 2 pick 2 pick 2 pick ;
: 3drop drop 2drop ;

: cell 2 ;
: cells cell * ;

: binary 2 base ! ;
: decimal 10 base ! ;
: hex 16 base ! ;

: u/   u/mod nip ;
: umod u/mod drop ;
: /    /mod nip ;
: mod  /mod drop ;

: min 2dup > if swap then drop ;
: max 2dup < if swap then drop ;

\ ( value min max -- value )
: clamp rot min max ;
: within[] 2 pick >r clamp r> = ;
: within[) 1- within[] ;

: aligned dup cell mod + ;
: align   here @ aligned here ! ;

: >cfa    >terminator 1+ ;
: last    latest @ >cfa ;
: recurse last go-now, ; immediate

\ ===

: >body      6 + ;
: >does      >body 3 - ;
: doesnt,    ['] exit c, idk, ;
: does-this! last >does xt! ;

: allot here +! ;

: create   word define something, doesnt, ['] exit c, this! ;
: does>    something, ['] does-this! xt, ['] exit c, this! ; immediate
: constant create , does> @ ;
: enum     dup constant 1+ ;
: flag     dup constant 1 lshift ;
: variable create cell allot ;

\ ===

: "? [char] " = ;

: string,
  next-char drop
  begin
    next-char dup "? 0=
  while
    c,
  repeat
  drop ;

\ ( -- len-ptr tailcall-ptr )
: data, something, something, go-somewhere, rot this! ;
: s" data, swap here @ string, how-far swap ! over-here! ; immediate

: hi s" hello" ;

hi ##type ##cr

bye


: +field
  over + swap
  create ,
  does> @ + ;

: field
  over aligned
  flip drop
  +field ;

0 cell field >a
  cell field >b
  cell field >c
constant size

0 >a
0 >b
0 >c
size ##.s


bye


\ TODO values, variables
\ TODO strings

\ should this file have to end with 'bye' or 'quit' ?

\ including files needs an interpreter
\ unless...
\ including files can be done with devices

bye

