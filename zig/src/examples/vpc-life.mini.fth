\ ===
\
\ conways game of life GUI
\
\ ===

: wrap ( val max -- ) tuck + swap mod ;

30 constant width
30 constant height
width height * constant size
create b0 size allot
create b1 size allot

b0 variable front
b1 variable back

: bswap ( -- )     front @ back @ front ! back ! ;
: f@    ( i -- n ) front @ + c@ ;
: b!    ( n i -- ) back @ + c! ;
: f!    ( n i -- ) front @ + c! ;

\ : xy>i ( x y -- n ) swap width wrap swap height wrap width * + ;

0 variable offx
0 variable offy

: >off offy ! offx ! ;

: off>i ( x y -- n )
  swap offx @ + width wrap swap
       offy @ + height wrap width * + ;
: offf@ ( x y -- n ) off>i f@ ;
: offb! ( x y n -- ) -rot off>i b! ;
: offf! ( x y n -- ) -rot off>i f! ;

: neighbors ( x y -- n ) >off
  -1 -1 offf@   0 -1 offf@ + 1 -1 offf@ +
  -1  0 offf@ +              1  0 offf@ +
  -1  1 offf@ + 0  1 offf@ + 1  1 offf@ + ;

: alive? ( x y -- n )
  2dup width * + f@ -rot neighbors
  tuck 2 = and swap 3 = or ;

doer cellp
doer rowp

: over-row ( y -- ) >r
  width 0 u>?|: dup r@ cellp 1+ loop then
  r> 3drop ;

: over-cells height 0 u>?|: dup over-row rowp 1+ loop then 2drop ;

: process
  make cellp 2dup alive? 1 and -rot width * + b! ;and
  make rowp  ;and
  over-cells ;

: offrect [ 5 tags, ]
  @0 offx @ + @1 offy @ + @2 offx @ + @3 offy @ + @4
  putrect ;

: draw
  make cellp
    2dup width * + front @ + c@ >r
    swap 10 * 10 + swap 10 * 10 + >off 0 0 9 9 r> offrect ;and
  make rowp ;and
  over-cells ;

: init b0 size erase b1 size erase ;

: set   1 offf! ;
: clear 0 offf! ;

: glider ( x y -- ) >off
  1 0 set 2 1 set 0 2 set
  1 2 set 2 2 set ;

talloc constant timer
0 true 10 u/ timer t!

init
0 0 glider

pdefault
hex
00 aa 00 2 pal!
decimal

0 0 640 400 2 putrect

make frame
  timer t@ if
    draw
    process
    bswap
  then ;

main
