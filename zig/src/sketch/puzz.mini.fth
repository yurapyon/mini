6 constant width
12 constant height
width height * constant #squares
: xy>i ( x y -- i ) width * + ;
: wrap ( val max -- ) tuck + swap mod ;

  0 enum %red
    enum %green
    enum %yellow
    enum %blue
constant #colors

: randc random #colors mod ;

randc
randc
randc
randc
.s cr

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
