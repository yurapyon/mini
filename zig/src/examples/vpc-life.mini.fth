\ ===
\
\ conways game of life GUI
\
\ ===

: wrap ( val max -- ) tuck + swap mod ;

20 constant width
15 constant height
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

0 [if]
: .cell if '#' else bl then emit ;

: .grid
  make cellp width * + front @ + c@ .cell ;and
  make rowp  cr ;and
  over-cells ;

: steps 0 |: dup . cr .grid 2dup u> if frame 1+ loop then 2drop ;

[then]

: init b0 size erase b1 size erase ;

: frame process bswap ;

: set   1 offf! ;
: clear 0 offf! ;

: glider ( x y -- ) >off
  1 0 set 2 1 set 0 2 set
  1 2 set 2 2 set ;

init
0 0 glider

make frame
  ;
