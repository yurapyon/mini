\ ===
\
\ conways game of life GUI
\
\ ===

64 constant width
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

0 variable offx
0 variable offy
: >offset offy ! offx ! ;

: offrect [ 5 tags, ]
  @0 offx @ + @1 offy @ + @2 offx @ + @3 offy @ + @4
  putrect ;

2 cells constant /coord
16 constant #coords
create coords #coords /coord * allot
0 variable coord#
: coord coords coord# /coord * + ;
: cclear 0 coord# ! 0 0 >offset ;
: >c     2dup offy +! offx +!
         swap coord !+ ! 1 coord# +! ;
: c>     coord @+ negate offx +! @ negate offy +!
         -1 coord# +! ;

\ ===

: offset+ ( x y -- x y )
  swap offx @ + width wrap swap offy @ + height wrap ;

: f@off ( x y -- n ) offset+ xy>i f@ ;

: neighbors ( x y -- n ) >offset
  -1 -1 f@off   0 -1 f@off + 1 -1 f@off +
  -1  0 f@off +              1  0 f@off +
  -1  1 f@off + 0  1 f@off + 1  1 f@off + ;

: alive? ( x y -- n )
  2dup xy>i f@ -rot neighbors
  tuck 2 = and swap 3 = or ;

\ ===

doer cellp
: over-row   ( y -- ) >r
  width 0 u>?|: dup r@ cellp 1+ loop then r> 3drop ;
: over-cells ( -- )
  height 0 u>?|: dup over-row 1+ loop then 2drop ;

: process
  make cellp 2dup alive? 1 and -rot xy>i b!
  ;and over-cells ;

: draw
  make cellp
    2dup xy>i f@ >r
    swap 8 * swap 8 * >c 0 0 7 7 r> offrect c>
  ;and cclear 20 20 >c over-cells c> ;

\ ===

: set   1 -rot offset+ xy>i f! ;
: clear 0 -rot offset+ xy>i f! ;

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

talloc constant timer
0 true 10 u/ timer t!

pdefault
hex
00 aa 00 2 pal!
decimal

make frame timer t@ if draw process bswap then ;

bclear
0 0 glider
45 30 lwss

0 0 640 400 2 putrect

main
