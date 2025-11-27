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

: pressed? 1 = ;

257 constant %enter
259 constant %bksp

\ todo how to catch error
: run ." running: " line type cr line evaluate clear-line start-line ;

make on-key pressed? if cond
    dup %enter = if drop run else
    dup %bksp =  if drop line> else
      drop
    endcond
  else
    drop
  then ;

make on-char nip >line ;

: init
  video-init
  start-line
  <v
  pdefault
  0 0 640 400 0 putrect
  v> ;

init

main
