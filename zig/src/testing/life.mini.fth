vocabulary life
life definitions

( x y dx dy -- x y )
: offset >r swap >r + r> r> + ;

20 constant width
15 constant height
width height * constant size
: xy>i width * + ;
: i>xy width /mod swap ;
: wrapxy height + height mod swap width + width mod swap ;

size double-buffer grid
: g!      true grid db.get + c! ;
: g@     false grid db.get + c@ ;
: guser! false grid db.get + c! ;

( i x y -- n )
: ioffset rot i>xy offset wrapxy xy>i ;

( i -- neighbors )
: neighbors >r
  r@ -1 -1 ioffset g@
  r@  0 -1 ioffset g@ +
  r@  1 -1 ioffset g@ +
  r@ -1  0 ioffset g@ +
  r@  1  0 ioffset g@ +
  r@ -1  1 ioffset g@ +
  r@  0  1 ioffset g@ +
  r@  1  1 ioffset g@ +
  r> drop ;

\ ( currcell neighbors -- t/f )
\ : alive? swap if 2 3 in[,] else 3 = then ;
: alive? dup 3 = -rot 2 = and or ;

: cell.next dup g@ over neighbors alive? 1 and over g! ;

: .cell if '#' else bl then emit ;
: ?cr 1+ width mod 0= if cr then ;
: .grid size 0 |: 2dup > if dup g@ .cell space dup ?cr 1+
  loop then 2drop ;

: init grid db.erase ;
: frame size 0 |: 2dup > if cell.next 1+ loop then 2drop ;
: life.next frame grid db.swap .grid ;

forth definitions
life

: set   wrapxy xy>i 1 swap guser! ;
: clear wrapxy xy>i 0 swap guser! ;
\ todo this is looking up the wrong next
\ : run   init |: next 1 sleeps loop ;
: run   s" clear" shell life.next 100 sleep loop ;
: steps 0 . cr .grid 0 |: 2dup > if dup 1+ . cr life.next
  1+ loop then 2drop ;

: now .grid ;


( x y -- )
: glider
  2dup 1 0 offset set
  2dup 2 1 offset set
  2dup 0 2 offset set
  2dup 1 2 offset set
       2 2 offset set ;

: lwss
  2dup 1 0 offset set
  2dup 4 0 offset set
  2dup 0 1 offset set
  2dup 0 2 offset set
  2dup 4 2 offset set
  2dup 0 3 offset set
  2dup 1 3 offset set
  2dup 2 3 offset set
       3 3 offset set ;

init

