\ -16 -8  0
\ |upd|id-|mem...
: buf 0xff00 , here @ 1024 allot value ;
buf b0 buf b1
: bswap b1 b0 to b1 to b0 ;
: update 1 b0 2 - c! ;
: clrupd 2 - 0 swap c! ;
: trysave dup 2 - c@ if dup clrupd dup 1- c@ swap bwrite else drop then ;
: bsave b0 trysave b1 trysave ;
: bempty 0xff00 b0 2 - ! 0xff00 b1 2 - ! ;
: flush bsave bempty ;
: buffer b1 trysave b1 1- c! b1 ;
: block cond
    dup b0 1- c@ = if drop else
    dup b1 1- c@ = if drop bswap else
    dup buffer bread bswap
  endcond b0 ;
0 value blk

\ TODO buffer load
: load ;
