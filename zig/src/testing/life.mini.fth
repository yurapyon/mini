vocabulary life
life definitions

20 constant width
20 constant height
width height * constant size

: xy>i swap height * + ;
: i>xy height /mod ;

size double-buffer grid
: g!      true grid db.get + c! ;
: g@     false grid db.get + c@ ;
: guser! false grid db.get + c! ;
: wrap size + size mod ;

( i -- neighbors )
: neighbors >r
  r@ width - 1- wrap g@
  r@ width -    wrap g@ +
  r@ width - 1+ wrap g@ +
  r@         1- wrap g@ +
  r@         1+ wrap g@ +
  r@ width + 1- wrap g@ +
  r@ width +    wrap g@ +
  r@ width + 1+ wrap g@ +
  r> drop ;

\ ( neighbors currcell -- t/f )
: live-or-die if 2 3 in[,] else 3 = then ;

: .cell if '#' else bl then emit ;
: ?cr 1+ width mod 0= if cr then ;
: .grid size 0 |: 2dup > if dup g@ .cell space dup ?cr 1+
  loop then 2drop ;

: init grid db.erase ;

: frame
  size 0 |: 2dup > if
    dup neighbors over g@ live-or-die 1 and over g!
  1+ loop then 2drop ;

: life.next frame grid db.swap .grid ;

forth definitions
life

: set   xy>i 1 swap wrap guser! ;
: clear xy>i 0 swap wrap guser! ;
\ todo this is looking up the wrong next
\ : run   init |: next 1 sleeps loop ;
: run   s" clear" shell life.next 100 sleep loop ;
: steps 0 . cr .grid 0 |: 2dup > if dup 1+ . cr life.next
  1+ loop then 2drop ;

: now .grid ;

( x y dx dy -- x y )
: offset >r swap >r + r> r> + ;

( x y -- )
: glider
  2dup 1 0 offset set
  2dup 2 1 offset set
  2dup 0 2 offset set
  2dup 1 2 offset set
       2 2 offset set ;

init

