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

make on-key        2drop ;
make on-mouse-move 2drop ;
make on-mouse-down 2drop ;
make on-char       2drop ;
make on-gamepad    3drop ;

doer frame

-1 value _chars
-1 value _screen

: putp     _screen i!xy ;
: putline  _screen i!line ;
: putrect  _screen i!rect ;
: blit     _screen i!blit ;
: blitline _screen i!blitline ;

: setmask   ( x0 y0 x1 y1 id -- ) true swap i!mask ;
: clearmask ( id -- )             >r 0 0 0 0 false r> i!mask ;

: scissor   ( x0 y0 x1 y1 -- ) _screen setmask ;
: unscissor ( -- )             _screen clearmask ;

: 3p@   ( addr -- r g b ) dup p@ swap 1+ dup p@ swap 1+ p@ ;
: pal@  ( n -- r g b )    3 * 3p@ ;
: cpal@ ( n -- r g b )    3 * $8000 or 3p@ ;

: 3p!   ( r g b addr -- ) tuck 2 + p! tuck 1 + p! p! ;
: pal!  ( r g b n -- )    3 * 3p! ;
: cpal! ( r g b n -- )    3 * $8000 or 3p! ;

: pdefault [ hex ]
  00 00 00 0 pal!
  ff ff ff 1 pal!
  ff ff ff 0 cpal!
  00 00 00 1 cpal!
  [ decimal ] ;

create events
  ' on-close      ,
  ' on-key        ,
  ' on-mouse-move ,
  ' on-mouse-down ,
  ' on-char       ,
  ' on-gamepad    ,

: poll! poll if cells events + @ execute loop then ;

true variable continue

make on-close false continue ! ;

: video-init image-ids to _chars to _screen ;

: main true continue ! |: continue @ if
    <v frame poll! v> 30 sleep
  loop then ;
