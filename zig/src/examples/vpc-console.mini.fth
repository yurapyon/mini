\ ===
\
\ WIP console
\
\ ===

: ppalette! 3 * tuck 2 + pcolors! tuck 1 + pcolors! pcolors! ;

hex
00 00 00 0 ppalette!
ff ff ff 1 ppalette!
decimal

0 0 640 400 0 prect

( i c -- )
: putc swap 8 3 * + 16 16 10 * * + chars! ;

create lbuf 128 allot
0 variable lat

: line lbuf lat @ ;

: clearline 0 lat @ 2 * range u>?|: dup 0 putc 1+ loop then 2drop ;

: putline line type cr
  0 lat @ range u>?|: dup 2 * over lbuf + c@ putc 1+ loop then 2drop ;

: bksp   lat @ if clearline -1 lat +! putline then ;
: record line + c! 1 lat +! putline ;
: run    ." running: " line type cr line evaluate clearline 0 lat ! ;

: pressed? 1 = ;

257 constant %enter
259 constant %bksp

\ todo should clear return stack somehow
: abort s0 s* ! 0 source-ptr ! source-len @ >in ! ;
:noname type '?' emit cr abort ; wnf !

make on-key pressed? if cond
    dup %enter = if drop run else
    dup %bksp =  if drop bksp else
      drop
    endcond
  else
    drop
  then ;

make on-char nip record ;

make on-mouse-down
  2drop ;

main
