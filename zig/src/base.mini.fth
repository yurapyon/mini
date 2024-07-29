word xorc!     define ] tuck c@ xor swap c! [ ' exit c,
word immediate define ] 0b01000000 latest @ >terminator xorc! [ ' exit c,
word hide      define ] 0b00100000 swap >terminator xorc! [ ' exit c,
word :         define ] word define latest @ hide ] [ ' exit c,
word ;         define ] ['] exit c, latest @ hide [ ' [ c, ' exit c, immediate

: bytes,   c, c, ;
: bytesLE, cell>bytes bytes, ;
: bytesBE, cell>bytes swap bytes, ;

: bytes!   tuck c! 1+ c! ;
: bytesLE! >r cell>bytes r> bytes! ;
: bytesBE! >r cell>bytes swap r> bytes! ;

: mkabsjump 0x8000 or ;
: absjump,  mkabsjump bytesBE, ;
: absjump!  >r mkabsjump r> bytesBE! ;

: [compile] ' absjump, ; immediate

: this    here @ swap ;
: howback here @ - ;
: howfar  this - ;

: idk,    0 c, ;
: smthng, ['] litc c, here @ idk, ;

: idunno,    idk, idk, ;
: something, ['] lit c, here @ idunno, ;
: this!      this bytesLE! ;

: jump,    ['] branch  c, here @ idk, ;
: jump0,   ['] branch0 c, here @ idk, ;
: to-here! dup howfar swap c! ;
: back!    tuck - swap c! ;

: if   jump0, ; immediate
: else jump, swap to-here! ; immediate
: then to-here! ; immediate

: begin here @ ; immediate
: until jump0, back! ; immediate
: again jump,  back! ; immediate

: while  [compile] if ; immediate
: repeat swap [compile] again [compile] then ; immediate

: char   word drop c@ ;
: [char] ['] litc c, char c, ; immediate

: \ begin next-char 10 = until ; immediate

: is()
  dup [char] ( = if  drop 1 [ ' exit c, ] then
      [char] ) = if      -1 [ ' exit c, ] then
  0 ;

: (
  1
  begin
    next-char is() +
    dup 0=
  until
  drop ; immediate

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

: within     ( val min max -- t/f )
  >r over r> ( val min val max )
  < -rot >= and ;

: min ( a b -- min ) 2dup > if swap then drop ;
: max ( a b -- max ) 2dup < if swap then drop ;
: clamp ( val min max -- clamped ) rot min max ;

: aligned dup cell mod + ;
: align   here @ aligned here ! ;

0 aligned
1 aligned
2 aligned
##.s

: >cfa >terminator 1+ ;
: last latest @ >cfa ;

\ ===

: >body       aligned 6 + ;
: >does       >body 3 - ;
: do-nothing, ['] exit c, idk, ;
: do-this!    last >does absjump! ;

: allot here +! ;

: create
  word define
  something, do-nothing, ['] exit c, this! ;

: does> something, ['] do-this! absjump, ['] exit c, this! ; immediate
( _
: does>
  state @ if
    something, ['] do-this! absjump, ['] exit c, this!
  else
    here @ do-this!
    latest @ hide
    ]
  then ; immediate
  )

: constant create , ; \ does> @ ;
\ : enum     dup constant 1+ ;
\ : flag     dup constant 1 lshift ;
\ : variable create cell allot ;

\ ===


\ : doesiit create , does> @ ;

1 constant wowxo

wowxo
##.s

bye

: recurse
  \ compiles the 'currently being defined' xt as a tailcall
  \ latest @ >cfa tailcall
  ; immediate

: "? [char] " = ;

: string,
  next-char drop
  begin
    next-char dup "? 0=
  while
    c,
  repeat
  drop ;

\ jump, only works with i8s, or 127 chars
\   for fullsized data,
\     you'd need to be able to compile tailcalls
\ ( -- jump-ptr len-ptr )
: datac, something, smthng, jump, rot this! swap ;
: s" datac, here @ string, howfar swap c! to-here! ; immediate

\ : hi s" hello" ;
\
\ hi ##type ##cr


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

size ##.s

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

