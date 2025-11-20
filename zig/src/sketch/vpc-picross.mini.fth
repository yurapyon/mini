vocabulary picross
picross definitions

30 constant maxw
30 constant maxh
maxw maxh * constant #squares
create squares #squares allot

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
  dup curr-hint !
  swap >hints/set @ cells erase
  0 last-read ! ;

: push-hint dup if
     1 curr-hint @ +!
   else
     last-read @ if cell curr-hint +! then
   then
   last-read ! ;

s[
  cell field >width
  cell field >height
     0 field >data
]s /puzzle

0 variable curr-puzzle

doer hlist
doer next
doer start

: build-hints ( start len -- )
  dup hlist start-hints
  start range check> if
    dup curr-puzzle @ + >data c@ push-hint
  next loop then
  2drop ;

: row
  make hlist hintsy ;and
  make next  1 + ;and
  make start curr-puzzle @ >width @ * curr-puzzle @ >width @ ;and
  build-hints ;

: col
  make hlist hintsx ;and
  make next  curr-puzzle @ >width @ + ;and
  make start curr-puzzle @ >width @ curr-puzzle @ >height @ * ;and
  build-hints ;

[then]

forth definitions

vocabulary puzzles
puzzles definitions

: puzzle create swap , , ;

: & 1 c, ;
: _ 0 c, ;

10 10 puzzle one
& _ & & & _ _ _ _ &
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
0 row
0 col
hintsy 32 dump
hintsx 32 dump

\ words cr


