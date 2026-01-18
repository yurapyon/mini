external poll
external deinit

external <v
external v>

external image-ids
external p!
external p@

external talloc
external tfree
external t!
external t@

external ialloc
external ifree
external i!mask
external i!fill
external i!rand
external i!xy
external i!line
external i!rect
external i!blit
external i!blitline

external chars!
external chars@

doer on-close
doer on-key
doer on-mouse-move
doer on-mouse-down
doer on-char
doer on-gamepad
doer on-gamepad-connection

make on-key                2drop ;
make on-mouse-move         2drop ;
make on-mouse-down         2drop ;
make on-char               2drop ;
make on-gamepad            3drop ;
make on-gamepad-connection 2drop ;

0 enum %g.a
  enum %g.b
  enum %g.x
  enum %g.y
  enum %g.lb
  enum %g.rb
  enum %g.back
  enum %g.start
  enum %g.guide
  enum %g.lthumb
  enum %g.rthumb
  enum %g.d-up
  enum %g.d-right
  enum %g.d-down
  enum %g.d-left
  enum %g.axis-lx
  enum %g.axis-ly
  enum %g.axis-rx
  enum %g.axis-ry
  enum %g.axis-lt
  enum %g.axis-rt
constant #g.buttons

-1 value _chars
-1 value _screen

: putp     <v _screen i!xy v> ;
: putline  <v _screen i!line v> ;
: putrect  <v _screen i!rect v> ;
: blit     <v _screen i!blit v> ;
: blitline <v _screen i!blitline v> ;

: setmask   ( x0 y0 x1 y1 id -- ) true swap i!mask ;
: clearmask ( id -- )             >r 0 0 0 0 false r> i!mask ;

: scissor   ( x0 y0 x1 y1 -- ) <v _screen setmask v> ;
: unscissor ( -- )             <v _screen clearmask v> ;

: 3p@   ( addr -- r g b ) <v dup p@ swap 1+ dup p@ swap 1+ p@ v> ;
: pal@  ( n -- r g b )    3 * 3p@ ;
: cpal@ ( n -- r g b )    3 * $8000 or 3p@ ;

: 3p!   ( r g b addr -- ) <v tuck 2 + p! tuck 1 + p! p! v> ;
: pal!  ( r g b n -- )    3 * 3p! ;
: cpal! ( r g b n -- )    3 * $8000 or 3p! ;

: pdefault [ hex ]
  00 00 00 0 pal!
  ff ff ff 1 pal!
  ff ff ff 0 cpal!
  00 00 00 1 cpal!
  [ decimal ] ;

create events
  ' on-close              ,
  ' on-key                ,
  ' on-mouse-move         ,
  ' on-mouse-down         ,
  ' on-char               ,
  ' on-gamepad            ,
  ' on-gamepad-connection ,

: poll! poll if cells events + @ execute loop then ;

true variable continue

make on-close false continue ! ;

: video-init image-ids to _chars to _screen ;

doer frame

: main true continue ! |: continue @ if
    frame poll! 30 sleep
  loop then ;
