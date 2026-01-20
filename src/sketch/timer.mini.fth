: counter talloc dup >r t! create r> , 0 , ;

: c.reset 0 swap cell + ! ;
: c.next  @+ t@ dup if swap +! else 2drop then ;
: c.wait  tuck c.next over cell + @ <= if c.reset true else drop false then ;

0 true 30 u/   counter frames
0 true 1000 u/ counter millis

0 [if]
talloc constant timer
0 true 20 u/ timer t!

make frame
  timer t@ dup if . ." sec" cr then
  ;

[then]

doer t

: setup |:
  make t  500 millis c.wait if ." abc" cr
  make t 2000 millis c.wait if ." def" cr loop
  then then ;

setup

make frame
  t
  \ anim c.next
  \ anim cell + @ 50 > if anim c.reset then
  \ anim cell + @ . cr
  ;

main
