external setxt
external close?
external draw/poll
external deinit
external image-ids
external p!
external p@
external i!xy
external i!line
external i!rect

external pbrush!
external pbrush@
external pbrush
external pbrushline
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

: putp _screen i!xy ;
: putline _screen i!line ;
: putrect _screen i!rect ;

: close? close? stay @ 0= or ;

: main frame draw/poll close? 0= if loop then deinit ;

