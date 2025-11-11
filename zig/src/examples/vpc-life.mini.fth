\ ===
\
\ conways game of life GUI
\
\ ===

( x y c -- )
: putchar >r 80 * + 2 * 16 16 10 * * + r> swap chars! ;

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

: offrect [ 5 tags, ]
  @0 offx @ + @1 offy @ + @2 offx @ + @3 offy @ + @4
  putrect ;

: offchar >r >r offx @ + r> offy @ + r> putchar ;

2 cells constant /coord
16 constant #coords
create coords #coords /coord * allot
0 variable coord#
: coord coords coord# /coord * + ;
: cclear 0 coord# ! 0 0 >offset ;
: >c     2dup offy +! offx +! swap coord !+ !
         1 coord# +! ;
: c>     coord @+ negate offx +! @ negate offy +!
         -1 coord# +! ;

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

: for-row ( y -- ) >r
  width 0 u>?|: dup r@ process 1+ loop then r> 3drop ;

: for-all ( -- )
  height 0 u>?|: dup for-row 1+ loop then 2drop ;

: next make process
    2dup alive? 1 and -rot xy>i b!
  ;and for-all bswap ;

: show make process
    2dup xy>i f@ >r
    swap 9 * swap 9 * >c 0 0 9 9 r> offrect c>
  ;and cclear 140 20 >c for-all c> ;

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

false variable playing
: toggle playing @ 0= playing ! ;

: background
    0  0 640 400 0 putrect
  130 10 510 390 1 putrect
  131 11 509 389 2 putrect ;

: offtype ( a n -- ) 1-
  |: 2dup + c@ over 0 rot offchar dup if 1- loop then 2drop ;

: label create current @ @ name 1/string swap , , offx @ , offy @ , ;
: l>stk @+ swap @+ swap @+ swap @ ;
: l>x   cell + @+ 8 * swap @ 8 * swap over + ;
: l>y   3 cells + @ 10 * dup 10 + ;

: l.draw    ( c l -- )
  0 0 >offset
  swap >r dup l>x rot l>y >r swap r> r> offrect ;
: l.print   ( l -- )   l>stk >offset offtype ;
: l.inside? ( x y l -- t/f ) tuck l>y in[,] -rot l>x in[,] and ;

1 1 >offset label %reset
1 3 >offset label %reset2

compiler definitions
: t" ['] >offset , [compile] s" ['] offtype , ;
forth definitions

: ui
  \ 1 1 t" play"
  \ 1 3 t" clear"
  \ 1 5 t" glider"
  \ 1 7 t" lwss"
  3 %reset l.draw %reset l.print
  3 %reset2 l.draw %reset2 l.print
  ;

: starting
  bclear
  7 0 glider
  10 1 glider
  20 3 glider
  30 0 glider
  45 15 lwss
  45 23 lwss
  45 31 lwss
  ;

0 variable mx
0 variable my
0 variable mx-last
0 variable my-last
false variable mheld

talloc constant timer
0 true 10 u/ timer t!

pdefault
hex
00 aa 00 2 pal!
11 11 99 3 pal!
decimal

: mnext mx @ mx-last ! my @ my-last ! my ! mx ! ;

: mpressed? $10 and ;
: shift?    $1 and ;

make on-mouse-move mnext ;

make on-mouse-down drop mpressed? dup mheld !
  if mx @ my @ cond
    2dup %reset  l.inside? if 2drop starting else
    2dup %reset2 l.inside? if 2drop ." reset2" cr else
      2drop
    endcond
  then ;

make frame timer t@ if show next then ;

bclear
7 0 glider
10 1 glider
20 3 glider
30 0 glider
45 15 lwss
45 23 lwss
45 31 lwss

background
ui

main
