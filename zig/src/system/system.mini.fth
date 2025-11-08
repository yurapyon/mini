external setxt
external close?
external draw/poll
external deinit
external image-ids
external p!
external p@
external i!mask
external i!fill
external i!rand
external i!xy
external i!line
external i!rect
external i!blit
external i!blitline

external ialloc
external ifree

external chars!
external chars@

doer on-key
doer on-mouse-move
doer on-mouse-down
doer on-char

' on-key        0 setxt
' on-mouse-move 1 setxt
' on-mouse-down 2 setxt
' on-char       3 setxt

make on-key        2drop ;
make on-mouse-move 2drop ;
make on-mouse-down 2drop ;
make on-char       2drop ;

doer frame

image-ids
constant _chars
constant _screen

: putp     _screen i!xy ;
: putline  _screen i!line ;
: putrect  _screen i!rect ;
: blit     _screen i!blit ;
: blitline _screen i!blitline ;

: setmask   ( x0 y0 x1 y1 id -- ) true swap i!mask ;
: clearmask ( id -- )             >r 0 0 0 0 false r> i!mask ;

: scissor   _screen setmask ;
: unscissor _screen clearmask ;

: close? close? stay @ 0= or ;

: main frame draw/poll close? 0= if loop then deinit ;

