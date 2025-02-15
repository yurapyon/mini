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

: u. <# #s #> type ;
: u.pad rot <# #s flip #pad #> type ;
: u.r bl u.pad ;
: u.0 '0' u.pad ;
: . u. space ;
: ? @ . ;

\ ===

0 [if]

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
  ;

: defpal [ hex ]
  00 00 00 0 setpal ff ff ff 1 setpal 80 80 80 2 setpal
  00 00 ff 2 setpal 00 ff 00 3 setpal ff 00 00 4 setpal
  00 ff ff 5 setpal ff ff 00 6 setpal ff 00 ff 7 setpal
  [ decimal ] ;

: init-video defchars defpal blankscr v-up ;

\ todo show boot image

[then]
