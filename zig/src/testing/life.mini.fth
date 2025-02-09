vocabulary life
life definitions

20 constant width
15 constant height
width height * constant size

: wrap>i ( x y -- i ) width height wrapxy width xy>i ;
: ixy+   ( i x y -- i ) rot width i>xy xy+ wrap>i ;

size double-buffer grid
: g@       true grid db.get + c@ ;
: gfront!  true grid db.get + c! ;
: g!      false grid db.get + c! ;

: neighbors ( i -- neighbors ) >r
  r@ -1 -1 ixy+ g@   r@ 0 -1 ixy+ g@ + r@ 1 -1 ixy+ g@ +
  r@ -1  0 ixy+ g@ + r@ 1  0 ixy+ g@ +
  r@ -1  1 ixy+ g@ + r@ 0  1 ixy+ g@ + r@ 1  1 ixy+ g@ +
  r> drop ;

: alive? ( cell neighbors -- t/f ) tuck 2 = and swap 3 = or ;

: cell.next dup g@ over neighbors alive? 1 and over g! ;

: .cell if '#' else bl then emit ;
: .grid size 0 |: 2dup > if dup g@ .cell dup width ?cr
  1+ loop then 2drop ;

: init  grid db.erase ;
: frame size 0 |: 2dup > if cell.next 1+ loop then 2drop ;
: next  frame grid db.swap ;

forth definitions
life

: init  init ;
: now   .grid ;
: set   wrap>i 1 swap gfront! ;
: clear wrap>i 0 swap gfront! ;
: steps 0 |: dup . cr .grid 2dup > if next 1+ loop then 2drop ;
: play  0 |: s" clear" shell dup . cr .grid 100 sleep
  2dup > if next 1+ loop then 2drop ;

: glider ( x y -- )
  2dup 1 0 xy+ set 2dup 2 1 xy+ set 2dup 0 2 xy+ set
  2dup 1 2 xy+ set      2 2 xy+ set ;

: lwss ( x y -- )
  2dup 1 0 xy+ set 2dup 4 0 xy+ set 2dup 0 1 xy+ set
  2dup 0 2 xy+ set 2dup 4 2 xy+ set 2dup 0 3 xy+ set
  2dup 1 3 xy+ set 2dup 2 3 xy+ set      3 3 xy+ set ;

init
