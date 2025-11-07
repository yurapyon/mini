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

\ 0 0 640 400 0 prect

create lbuf 128 allot
0 variable lat

: line lbuf lat @ ;

: record line + c! 1 lat +! line type cr ;
: run    ." run:" line type cr line evaluate 0 lat ! ;

: pressed? 1 = ;

257 constant %enter

make on-key pressed? if cond
    dup %enter = if run else
      drop
    endcond
  else
    drop
  then ;

make on-char nip record ;

main
