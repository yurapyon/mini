: xy* [by2] * ;
: xy/ [by2] / ;

: draw-chars
  256 0 |: 2dup u> if
    dup 32 /mod 6 8 xy* third 1 putc
  1+ loop then 2drop ;

( x y -- t/f )
: in-chars? 256 u< swap 48 u< and ;

( x y -- idx )
: clicked-ch 6 8 xy/ swap 32 * + ;

0 value active-ch
create active-ch-buf 6 allot

: show-active
  active-ch-buf active-ch getchar
  6 0 |: 2dup u> if dup active-ch-buf + c@ . cr 1+ loop 2drop ;

\ ===

true value first-frame

: frame
  first-frame if
    init-video
    draw-chars v-up
    false to first-frame
  then
  ;

: keydown
  \ panic
  ;

0 value mx
0 value my

: mousemove to my to mx ;

: mousedown
.2 cr
mx my in-chars? if
mx my clicked-ch to active-ch
show-active
then ;

' frame     0 sysxt!
' mousemove 2 sysxt!
' mousedown 3 sysxt!
