vocabulary picross
picross definitions

\ ===

30 constant maxw
30 constant maxh
maxw maxh * constant #squares
create squares #squares allot

: sq.clear squares #squares erase ;

0   enum %X
    enum %O
constant %clear

s[
  cell field >width
  cell field >height
     0 field >data
]s /puzzle

: puzzle create swap , , ;

0 variable curr-puzzle
: width curr-puzzle @ >width @ ;
: height curr-puzzle @ >height @ ;

: >p>s ( x y -- p-addr s-addr )
  width * + dup curr-puzzle + over squares + ;

: 2= ( a b c d -- a=c&b=d ) >r swap >r = r> r> = and ;

0   enum %ok
    enum %bad
constant %unk

create fuzzy-check
( 0 %X     ) %ok ,
( 0 %O     ) %bad ,
( 0 %clear ) %unk ,
( 1 %X     ) %bad ,
( 1 %O     ) %ok ,
( 1 %clear ) %unk ,

create final-check
( 0 %X     ) %ok ,
( 0 %O     ) %bad ,
( 0 %clear ) %ok ,
( 1 %X     ) %bad ,
( 1 %O     ) %ok ,
( 1 %clear ) %bad ,

0 variable check-table

user-check check-table !

: check ( x y -- status ) >p>s swap @ 3 * swap @ + check-table @ + @ ;

\ ===

doer i.next
doer i.check
doer i.each

: row> ( n -- end start )
  make i.next  1+ ;and
  make i.check >  ;and
  width * width range ;

: col> ( n -- end start )
  make next    width + ;and
  make i.check >       ;and
  width height * range ;

: go ( end start -- )
  |: 2dup i.check if
    dup curr-puzzle @ + >data c@ i.each
    i.next
  loop then ;

\ 0 hintsy hints 0 row> go
\ checks 0 row> go

s[
  cell field >#sets
  cell field >hints/set
     0 field >hints
]s /hints

: hints create 2dup * flip , , allot ;

maxw maxh 2 / hints hintsx
maxh maxw 2 / hints hintsy

0 variable curr-hint
0 variable last-read

: start-hints ( set hints -- )
  tuck >hints/set @ * over >hints + ( hints addr )
  dup curr-hint ! swap >hints/set @ erase
  0 last-read ! ;

: push-hint dup if 1 curr-hint @ +c!  else
   last-read @ if 1 curr-hint +! then then
   last-read ! ;

: hints make i.each push-hint ;and start-hints ;

0 [if]
doer hlist
doer inc
doer start

: build-hints ( start len -- )
  dup hlist start-hints
  start range check> if
    dup curr-puzzle @ + >data c@ push-hint
    inc +
  loop then
  2drop ;

: rows
  make hlist hintsy        ;and
  make inc   1             ;and
  make start width * width ;

: cols
  make hlist hintsx         ;and
  make inc   width          ;and
  make start width height * ;

: all-hints
  rows height 0 check> if dup build-hints 1+ loop then
  cols width  0 check> if dup build-hints 1+ loop then ;
[then]


forth definitions

vocabulary puzzles
puzzles definitions

: & 1 c, ;
: _ 0 c, ;

10 10 puzzle one
& & & & & _ _ _ _ &
& _ _ _ _ & _ _ _ _
& & _ _ _ & _ _ _ _
& & _ _ _ & _ _ _ _
& _ _ _ _ & _ _ _ _
& _ _ _ _ & _ _ _ _
& & _ _ _ & _ _ _ _
& _ _ _ _ & _ _ _ _
& _ _ _ _ & _ _ _ _
& _ _ _ _ & _ _ _ _
& _ _ _ _ & _ _ _ _

10 10 puzzle two
& _ _ _ _ _ _ _ _ &
& _ _ _ _ & _ _ _ _
& _ _ _ _ & _ _ _ _
& _ _ _ _ & _ _ _ _
& _ _ _ _ & _ _ _ _
& _ _ _ _ & _ _ _ _
& _ _ _ _ & _ _ _ _
& _ _ _ _ & _ _ _ _
& _ _ _ _ & _ _ _ _
& _ _ _ _ & _ _ _ _
& _ _ _ _ & _ _ _ _

\ ===

picross

puzzles one picross curr-puzzle !
all-hints
hintsy 32 dump
hintsx 32 dump

\ words cr


