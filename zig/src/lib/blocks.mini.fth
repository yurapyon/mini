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

create load-stack saved-max cells allot
load-stack value ls-tos

: save-blk
  b0 1- c@ ls-tos !
  cell +to ls-tos ;

: restore-blk
  cell negate +to ls-tos
  ls-tos @ block drop ;

\ todo
\ this would break if you 'list' a block from a block that's loading
: blk b0 1- c@ ;

: load save-blk block 1024 evaluate restore-blk ;
: thru swap |: 2dup >= if dup load 1+ loop then 2drop ;

\ todo '\' comments
