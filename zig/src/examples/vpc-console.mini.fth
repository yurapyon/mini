\ ===
\
\ WIP console
\
\ ===

( x y c -- )
: putchar >r 80 * + 2 * r> swap chars! ;

0 variable cx
0 variable cy

: >cursor cy ! cx ! ;
: +char   >r cx @ cy @ r> putchar 1 cx +! ;
: -char   -1 cx +! >r cx @ cy @ r> putchar ;

\ ===

create line-buf 80 allot
0 variable line-at
: line line-buf line-at @ ;

: start-line 0 0 >cursor ;
: clear-line 80 0 check> if dup 0 0 putchar 1+ loop then 2drop 0 line-at ! ;
: >line      dup +char line + c! 1 line-at +! ;
: line>      line-at @ if 0 -char -1 line-at +! then ;

\ ===

create history 80 40 * allot
history 80 40 * blank

: >history ( str len -- )
  history history 80 + 80 39 * move
  history 80 blank
  history swap move ;

: .history
  history       80 type cr
  history  80 + 80 type cr
  history 160 + 80 type cr ;

\ ===

: pressed? 1 = ;

257 constant %enter
259 constant %bksp

\ todo how to catch error
: run ." running: "
  line type cr
  line evaluate
  line >history .history
  <v clear-line start-line v> ;

make on-key pressed? if cond
    dup %enter = if drop run else
    dup %bksp =  if drop <v line> v> else
      drop
    endcond
  else
    drop
  then ;

make on-char nip <v >line v> ;

: main true continue ! |: continue @ if
    frame poll! 30 sleep
  loop then ;

: start
  video-init
  clear-line
  start-line
  <v
    pdefault
    0 0 640 400 0 putrect
  v>
  main ;

' start 12 !
quit
