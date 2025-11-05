: thingy  tailcall .r ;

: thingy2 tailcall thingy ;

: thingy3 tailcall thingy2 ;

.r
cr

thingy
cr
thingy2
cr
thingy3
cr
thingy
cr
