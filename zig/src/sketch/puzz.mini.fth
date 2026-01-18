: -trailing dup if 2dup + 1- c@ bl = if 1- loop then then ;

\ : randfill ( addr len mod -- ) >r range check> if random r@ mod over ! cell + loop then r> 3drop ;

: count, 0 check> if dup , 1+ loop then 2drop ;

6 constant width
12 constant height
width height * constant #squares
create squares #squares allot

: xy>i ( x y -- i ) width * + ;
: wrap ( val max -- ) tuck + swap mod ;

  0 enum %red
    enum %green
    enum %yellow
    enum %blue
constant #colors

create colors-buf 8 count,
0 variable colors-at

1235 >rng
colors-buf 16 dump
colors-buf 8 shuffle
colors-buf 16 dump
colors-buf 8 shuffle
colors-buf 16 dump
colors-buf 8 shuffle
colors-buf 16 dump
colors-buf 8 shuffle
colors-buf 16 dump

\ : nextc
  \ colors-buf #colors shuffle
  \ ;

: randc random #colors mod ;

: c>str d" red   green yellowblue  " swap 6 * + 6 ;
: .color c>str -trailing type ;
: .square '[' emit c>str drop c@ emit ']' emit ;

doer each-grid
: for-grid #squares 0 check> if each-grid 1+ loop then 2drop ;

: randg make each-grid randc over squares + c! ;and for-grid ;

: ?cr 1+ width mod 0= if cr then ;
: .squares make each-grid dup squares + c@ .square dup ?cr ;and for-grid ;

\ : swap*c ( a* b* -- ) over c@ flip over c@ swap c! c! ;

: nextg
  squares width + squares #squares width - move
  squares #squares width - + 6 range
  check> if dup randc swap c! 1+ loop then
  2drop
  ;

randg .squares cr
nextg .squares cr
nextg .squares cr

\ ===

\ match finder

6 constant goal-width
6 constant goal-height
create goal goal-width goal-height * allot

: set-goal ;

0 variable goal-w
0 variable goal-h

0 variable search-root
0 variable search-idx

\ ===

\ randc .square
\ randc .square
\ randc .square
\ randc .square
\ cr

0 [if]
create squares #squares 2 * allot
squares            variable bfront
squares #squares + variable bback
: bclear ( -- )     squares #squares 2 * erase ;
: bswap  ( -- )     bfront @ bback @ bfront ! bback ! ;
: f@     ( i -- n ) bfront @ + c@ ;
: b!     ( n i -- ) bback @ + c! ;
: f!     ( n i -- ) bfront @ + c! ;
[then]
