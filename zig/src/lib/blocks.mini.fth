: swapvars over @ over @ 2swap >r ! r> ! ;

s[
  cell field >bb.id
  cell field >bb.updated
  1024 field >bb.data
]s blkbuf

2 constant blkbuf-ct
create blkbufs blkbuf blkbuf-ct * allot
blkbufs blkbuf blkbuf-ct * erase

variable b0
variable b1
blkbufs b0 !
blkbufs blkbuf + b1 !

: bb.swap b0 b1 swapvars ;

: clrupd >bb.updated false swap ! ;
: bempty dup clrupd >bb.id 0xffff swap ! ;
: bsave dup clrupd dup >bb.id @ swap >bb.data bwrite ;
: trybsave dup >bb.updated @ if bsave else drop then ;
: update b0 @ >bb.updated true swap ! ;
: buffer b1 @ dup trybsave tuck >bb.id ! >bb.data ;
: block cond
    dup b0 @ >bb.id @ = if drop else
    dup b1 @ >bb.id @ = if drop bb.swap else
    dup buffer bread bb.swap
  endcond b0 @ >bb.data ;
: save-buffers b0 @ trybsave b1 @ trybsave ;
: empty-buffers b0 @ bempty b1 @ bempty ;
: flush save-buffers empty-buffers ;

empty-buffers

: blk b0 @ >bb.data ;

: load block 1024 evaluate ;
: thru swap |: 2dup >= if dup load 1+ loop then 2drop ;
: wipe blk 1024 32 fill update ;

quit

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
