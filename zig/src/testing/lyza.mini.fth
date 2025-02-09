vocabulary lyza
lyza definitions

\ use blocks

\ collision map
\ 4b flags, 2b, 2b cycle
\   0           0 1 2 3
\ 3 _ 1
\   2
create collisions 1024 allot

1024 double-buffer notes


forth definitions
lyza





quit

here @ constant _start

\ main

20 constant width
20 constant height
width height * constant squares

: xy>i width * + ;
: i>yx width /mod ;

\ ===

\ collision map
\ 4b flags, 2b, 2b cycle
\   0           0 1 2 3
\ 3 _ 1
\   2
create collisions squares allot

create grid squares allot
: g[] grid + ;

\ : set grid + ! ;
\ : unset 0 swap grid + ! ;

\ notes, front and back buffer
\ 8b
create notes squares 2 * allot
variable front
variable back
notes           front !
notes squares + back !

: swapb front @ back @ front ! back ! ;
: write back @ + c! ;
: read  front @ + c@ ;

\ ===

\ grid processing

\ i is current cell
\ j is output cell
variable i
variable j

\ ===

2 cells constant machine
create machines 64 machine * allot
: m[] machine * machine + ;
: m! flip m[] 1+ c!+ ! ;

\ 3b, 1b outputs?, 4b walls

\ conveyor
0x01
0b000_1_0010
\   _
\ _ v _
\   *
:noname
  \ on activate
  ;
m!

\ bridge in
0x02
0b000_0_0111
\   _
\ | v |
\   |
:noname
  \ on activate
  ;
m!

\ bridge out
0x03
0b000_1_1111
\   |
\ | v |
\   *
:noname
  \ on activate
  ;
m!

\ +
0x10
0b000_0_1111
\   |
\ | v |
\   |
:noname
  \ on activate
  ;
m!

\ copy
0x20
0b000_1_1111
\   |
\ | v |
\   *
:noname
  \ on activate
  ;
m!

\ machine grid
\ 6b type, 2b rotation
\ machine types
\ 000000 blank
\ normal
\ 000001 conveyor
\ 000010 bridge in
\ 000011 bridge out
\ modifiers
\ 010000 +
\ 010001 -
\ 010010 *
\ 010011 /
\ generators
\ 100000 copy
\ 100001 copy right
\ 100010 copy left
\ side effect
\ 110000 midi

\ ===

\ looks up a machine and runs it
: lookup
  ;

: process
  2dup > if
    dup i !
    \ TODO
    dup g[] . cr
    1+ recurse
  then 2drop ;


\ ======

." memory usage" cr

width u. ." x" height u. ." : "
_start dist . cr

." words: "
_start dist
squares -
squares -
squares 2 * -
. cr

\ ======

quit

\ machine grid

\ ground, collision, collision counter
3 constant square

create grid squares square * allot
: g[i] square * grid + ;

: setg  g[i] c! ;
: setc+ g[i] 1+ +c! ;

\ ( i -- collisions )
: countc
  g[i] 1+ >r
  r@ 1+ c@
  dup 1+ r@ c@ mod
  r> 1+ c! ;

\ notes buffer

create buffer squares 2 * allot
variable front
variable back
buffer front !
buffer squares + back !

: swapb front @ back @ front ! back ! ;
: write back @ + c! ;
: read  front @ + c@ ;

: move-note swap read swap write ;

: try-move
  over n@ if
    dup countc 0= if move-note else 2drop then
  then ;

\ ===

: move-notes
  2dup > if

  1+ recurse then 2drop
  ;

: play ;

: lyza
  move-notes
  play ;

dist
squares square * -
squares -
squares 2 * -
. cr

quit

\ square
\ 8      8    8
\ ground note lock
3 constant square

20 constant width
20 constant height
width height * constant squares
create grid squares square * allot

here @

: g[i]  square * grid + ;
: g[xy] width * + g[i] ;

variable offset

: ground 0 offset ! ;
: notes  1 offset ! ;
: locks  2 offset ! ;

: clear
  2dup > if
    dup g[i] offset @ + 0 swap c!
    1+ recurse
  then 2drop ;

: .square
  c@+ ?dup if emit else [char] . emit then
  c@+ ?dup if 2 u.0 else [char] _ 2 repeat then
  c@ if [char] ] emit else space then
  ;

: print
  hex
  2dup > if
    dup g[i] .square
    dup width mod width 1- = if cr then
    1+ recurse
  then 2drop ;

: process
  2dup > if
    dup g[i] 2 + c@ if 1+ return then
    dup g[i] c@+ case
      [char] > of c@ over 1+ g[i] 1+ c! endof
    endcase
    over 1 g[i] 2 + c!
    1+ recurse
  then 2drop ;

\ ===

: set g[xy] offset @ + c! ;

ground
squares 0 clear
char > 0 0 set
char > 1 0 set
char > 2 0 set

notes
squares 0 clear
64 0 0 set

locks squares 0 clear
squares 0 print cr

locks squares 0 clear
squares 0 process
squares 0 print cr

locks squares 0 clear
squares 0 process
squares 0 print cr

dist . cr

bye

: set >grid c! ;
: setl >grid 1+ c! ;

: lockc 1+ 1 swap c! ;

variable i

: yx i @ width /mod ;
: xy yx swap ;
: g[i] i @ 2 * grid + ;

: wrap >r width + width mod r> height + height mod ;

variable on-each

:noname 2dup > if dup i ! on-each @ execute 1+ recurse then 2drop ;
: loop width height * 0 [ , ] ;

: .cell c@+ emit c@ if [char] ` else bl then emit ;

    : place wrap >grid c!+ 1 swap c! ;

: clear   on-each assign [char] _ g[i] c! ;
: print   on-each assign g[i] .cell xy drop width 1 - = if cr then ;
: lock    on-each assign 1 g[i] 1+ c! ;
: unlock  on-each assign 0 g[i] 1+ c! ;
: process on-each assign
  g[i] 1+ c@ if return then
  g[i] c@ case
    [char] * of [char] _ xy set endof
    [char] n of [char] * xy set [char] n xy 1-      place endof
    [char] s of [char] * xy set [char] s xy 1+      place endof
    [char] e of [char] * xy set [char] e yx 1+ swap place endof
    [char] w of [char] * xy set [char] w yx 1- swap place endof
  endcase
  g[i] lockc ;

clear loop
unlock loop

char n 0 2 set
print loop cr

unlock loop process loop print loop cr

unlock loop process loop print loop cr
unlock loop process loop print loop cr
unlock loop process loop print loop cr
unlock loop process loop print loop cr


dist . cr

quit


: process-each each-cell assign
  c@ case
  [char] 0 of xy [char] a set endof
  endcase
  ;

\ : lyza
  \ process
  \ print
  \ recurse ;
