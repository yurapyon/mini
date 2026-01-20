\ ===
\
\ conways game of life GUI
\
\ ===

\ todo this code is kinda messy

( x y c -- )
: putchar >r 80 * + 2 * r> swap chars! ;

\ ===

40 constant width
40 constant height
width height * constant #squares
: xy>i ( x y -- i ) width * + ;
: wrap ( val max -- ) tuck + swap mod ;

create squares #squares 2 * allot
squares            variable bfront
squares #squares + variable bback
: bclear ( -- )     squares #squares 2 * erase ;
: bswap  ( -- )     bfront @ bback @ bfront ! bback ! ;
: f@     ( i -- n ) bfront @ + c@ ;
: b!     ( n i -- ) bback @ + c! ;
: f!     ( n i -- ) bfront @ + c! ;

\ ===

0 variable offx
0 variable offy
: >offset offy ! offx ! ;
: offset+ swap offx @ + swap offy @ + ;
: offset2+ >r >r offset+ r> r> offset+ ;

: offrect >r offset2+ r> putrect ;
: offchar >r offset+ r> putchar ;

2 cells constant /coord
16 constant #coords
create coords #coords /coord * allot
0 variable coord#
: coord coords coord# @ /coord * + ;
: cclear 0 coord# ! 0 0 >offset ;
: >c     offy @ offx @ coord !+ ! offset+ >offset 1 coord# +! ;
: c>     -1 coord# +! coord @+ swap @ >offset ;

\ ===

: grid+ ( x y -- x y )
  swap offx @ + width wrap swap offy @ + height wrap ;

: f@off ( x y -- n ) grid+ xy>i f@ ;

: neighbors ( x y -- n ) >offset
  -1 -1 f@off   0 -1 f@off + 1 -1 f@off +
  -1  0 f@off +              1  0 f@off +
  -1  1 f@off + 0  1 f@off + 1  1 f@off + ;

: alive? ( x y -- n )
  2dup xy>i f@ -rot neighbors
  tuck 2 = and swap 3 = or ;

\ ===

doer process

: for-row ( y -- ) >r width 0
  check> if dup r@ process 1+ loop then r> 3drop ;

: for-all ( -- ) height 0
  check> if dup for-row 1+ loop then 2drop ;

: g.update make process
    2dup alive? 1 and -rot xy>i b!
  ;and for-all bswap ;

: g.draw make process
    2dup xy>i f@ >r
    swap 9 * swap 9 * >c 0 0 9 9 r> offrect c>
  ;and cclear 140 20 >c for-all c> ;

: px>grid swap 140 - 9 / swap 20 - 9 / ;
: in-grid?
  swap 140 [ width 9 * 140 + ] literal in[,]
  swap  20 [ height 9 * 20 + ] literal in[,] and ;

\ ui ===

: offtype ( a n -- ) 1-
  |: 2dup + c@ over 0 rot offchar dup if 1- loop then 2drop ;

: label create current @ @ name 1/string swap , , swap , , ;
: l>stk @+ swap @+ swap @+ swap @ ;
: l>x   cell + @+ 8 * swap @ 8 * swap over + ;
: l>y   3 cells + @ 10 * dup 10 + ;

: l.draw    ( c l -- )
  0 0 >offset
  swap >r dup l>x rot l>y >r swap r> r> offrect ;
: l.print   ( l -- )   l>stk >offset offtype ;
: l.inside? ( x y l -- t/f ) tuck l>y in[,] -rot l>x in[,] and ;

also compiler definitions
: t" ['] >offset , [compile] s" ['] offtype , ;
previous definitions

\ note, unused ===

0 [if]

doer mmove
doer mclick

: region: ( x0 y0 x1 y1 -- )
  0 0 define >r flip , , , r> , [compile] ] ;

: in-region? ( x y r -- t/f )
  >cfa >r
    r@ cell + @ r@ 3 cells + @ in[,] swap
    r@        @ r@ 2 cells + @ in[,] and
  r> drop ;

vocabulary regions
also regions definitions

0 0 640 480 region:
  make mmove  2drop                ;and
  make mclick 2drop ." clickbg" cr ;

0 0 10 10 region:
  make mmove  swap . . cr           ;and
  make mclick ." click" swap . . cr ;

previous definitions

: (test) ( x y a -- )
  check!0 if
    3dup in-region? if
      >cfa 4 cells + >r 2drop exit
    else
      @ loop
    then
  then 3drop ;

: test regions context @ @ (test) ;

make mmove 2drop ;
make mclick 2drop ;

[then]

\ ===

: set   1 -rot grid+ xy>i f! ;
: clear 0 -rot grid+ xy>i f! ;

: glider ( x y -- ) >offset
  1 0 set 2 1 set 0 2 set
  1 2 set 2 2 set ;

: lwss ( x y -- ) >offset
  1 0 set 4 0 set 0 1 set
  0 2 set 4 2 set 0 3 set
  1 3 set 2 3 set 3 3 set ;

\ ===

0 variable mx
0 variable my
0 variable mx-last
0 variable my-last
false variable mheld

\ ===

doer show
doer toggle
doer %tport
doer click-grid

4 variable active

\ ===

: background
    0  0 640 400 0 putrect
  130 10 510 390 1 putrect
  131 11 509 389 2 putrect ;

1 0 label %>>
1 0 label %||
1 2 label %reset
1 4 label %draw
1 6 label %glider
1 8 label %lwss

: l.button ( l -- )
  >r
  mx @ my @ r@ l.inside? if mheld @ if 5 else 4 then else 3 then
  r@ l.draw r> l.print ;

: ui
  %tport l.button
  %reset l.button
  %draw l.button
  %glider l.button
  %lwss l.button
  0 4 0 putchar
  0 6 0 putchar
  0 8 0 putchar
  0 active @ '*' putchar
  ;

: reset
  bclear
  \ 7 0 glider
  \ 10 1 glider
  \ 20 3 glider
  \ 30 0 glider
  \ 45 15 lwss
  \ 45 23 lwss
  \ 45 31 lwss ;
  ;

defer pause

: play
  make show   g.update g.draw ;and
  make toggle pause           ;and
  make %tport %||             ;

:noname
  make show   g.draw ;and
  make toggle play   ;and
  make %tport %>>    ;
  is pause

\ ===

talloc constant timer
0 true 10 u/ timer t!

pdefault
hex
00 aa 00 2 pal!
22 22 bb 3 pal!
66 11 11 4 pal!
99 00 00 5 pal!
decimal

: mnext mx @ mx-last ! my @ my-last ! my ! mx ! ;

: mpressed? $10 and ;
: shift?    $1 and ;

make on-mouse-move mnext ui ;

make on-mouse-down drop mpressed? dup mheld !
  if mx @ my @ cond
    2dup %tport  l.inside? if 2drop toggle else
    2dup %reset  l.inside? if 2drop reset else
    2dup %draw   l.inside? if 2drop make click-grid cclear set ;and 4 active ! else
    2dup %glider l.inside? if 2drop make click-grid glider     ;and 6 active ! else
    2dup %lwss   l.inside? if 2drop make click-grid lwss       ;and 8 active ! else
    2dup in-grid?          if px>grid click-grid else
      2drop
    endcond
  then
  ui ;

make frame timer t@ if show then ;

bclear
7 0 glider
10 1 glider
20 3 glider
30 0 glider
45 15 lwss
45 23 lwss
45 31 lwss

video-init
<v
play
background
ui
v>

main
