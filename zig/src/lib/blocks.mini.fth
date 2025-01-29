\ 0   8   16
\ |upd|id-|mem...
: buf, here @ 0xff00 , 1024 allot ;
buf, value buf0
buf, value buf1
: bswap buf1 buf0 to buf1 to buf0 ;
: trysave dup c@ if 0 over c! dup 1+ c@ swap 2 + bwrite else drop then ;
: buffer buf1 trysave buf1 1+ c! buf1 2 + ;
: update 1 buf0 c! ;
: block cond
  dup buf0 1+ c@ = if  drop else
  dup buf1 1+ c@ = if bswap else
  dup buffer bread bswap
  endcond buf0 2 + ;
: save-buffers buf0 trysave buf1 trysave ;
: flush save-buffers 0xff00 buf0 ! 0xff00 buf1 ! ;
: blk buf0 2 + ;
\ TODO
: load ;
