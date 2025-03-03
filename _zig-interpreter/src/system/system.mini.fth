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

: .2 swap . . ;
: .3 flip . . . ;

\ ===

: pixels!+ tuck pixels! 1+ ;

: setpal >r flip r> 3 * pixels!+ pixels!+ pixels!+ drop ;

: debug-line >r
  640 0 |: 2dup > if dup 30 r@ + r@ putp 1+ loop then 2drop
  r> drop ;

: gray dup dup 16 255 keepin ;

: % 255 100 */ ;

: default-palette 0 % gray 0 setpal
  20 % gray 1 setpal 60 % gray 2 setpal 100 % gray 3 setpal
  [ hex ]
  00 00 f0 4 setpal 00 f0 00 5 setpal f0 00 00 6 setpal
  00 f0 f0 7 setpal f0 f0 00 8 setpal f0 00 f0 9 setpal
  00 60 c0 a setpal 60 c0 00 b setpal c0 00 60 c setpal
  40 80 f0 d setpal 80 f0 40 e setpal f0 40 80 f setpal
  [ decimal ] ;

: blline >r
  640 0 |: 2dup > if dup r@ 1 putp 1+ loop then 2drop
  r> drop ;

: thing
  \ 16 0 |: 2dup > if dup debug-line 1+ loop then 2drop
  400 0 |: 2dup > if dup blline 1+ loop then 2drop
  v-up
  ;

  default-palette
  \ thing

: putc 2 * 2584 + characters! ;
: puta 2 * 2585 + characters! ;
: puts 24 + characters! ;
: putsprite 16 i>xy 160 * + >r
160 0 do.u> rot over r@ + puts 16 + godo 2drop
r> drop
;

hex
00 00 00 00 00 00 00 00 00 00
decimal
0 putsprite

hex
00 82 82 82 fe 42 22 12 0a 06
decimal
255 putsprite


0 0 putc
0b00010111 0 puta

20 1 putc
2  1 puta

0 2 putc
0b00000011 2 puta

1 80 putc
0b00000011 80 puta

2 160 putc
0b00000011 160 puta
v-up

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
