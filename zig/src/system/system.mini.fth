\ todo this is just debug stuff

: emit __emit ;
: space bl emit ;
: spaces 0 |: 2dup > if space 1+ loop then 2drop ;
: cr 10 emit ;
: printable 32 126 in[,] ;
: print dup printable 0= if drop '.' then emit ;
: .print 2dup > if c@+ print loop then 2drop ;
: .chars 2dup > if c@+ emit loop then 2drop ;
: type range .chars ;
: ." [compile] s" type ;
compiler definitions
: ." [compile] s" ['] type , ;
forth definitions
:noname type '?' emit cr ; onwnf !

\ ===

: u. <# #s #> type ;
: u.pad rot <# #s flip #pad #> type ;
: u.r bl u.pad ;
: u.0 '0' u.pad ;
: . u. space ;
: ? @ . ;

: fillpage >r
  0xffff 0 |: 2dup u> if third over r@ putp 1+ loop then 2drop
  r> 2drop ;
: fillscr dup 0 fillpage 1 fillpage ;
: blankscr 0 fillscr ;

: fillline
  ;

: defchars
  d" \x0f\x3f\xff\xff\x3f\x0f" 0 setchar
  d" \x08\x48\x88\x88\x48\x08" 1 setchar
  d" \x08\x48\x88\x88\x48\x08" 65 setchar
  ;

hex
: defpal
  00 00 00 0 setpal
  ff ff ff 1 setpal
  ;

decimal

: init-video
  defchars defpal
  blankscr
  \ 0 0 0 1 putc
  \ 6 0 1 1 putc
  v-up
  ;

0 [if]
: __frame
  first-frame if frame0 false to first-frame then
  ;

: __keydown
  \ panic
  ;

: __mousemove
  \ swap . . cr
  2drop
  \ panic
  ;

[then]
