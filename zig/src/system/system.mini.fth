external setxt
external close?
external draw/poll
external deinit
external pcolors!
external pcolors@
external pset
external pline
external prect
external pbrush!
external pbrush@
external pbrush
external pbrushline

doer on-mouse-move
doer on-mouse-down
doer on-key
doer frame

: main frame draw/poll close? 0= if loop then deinit ;

' on-key        0 setxt
' on-mouse-move 1 setxt
' on-mouse-down 2 setxt

