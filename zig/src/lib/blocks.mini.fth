s[ cell field >bb.id cell field >bb.upd 1024 field >bb.data
]s blkbuf

2 constant blkbuf-ct
create blkbufs blkbuf blkbuf-ct * allot
blkbufs variable b0 blkbufs blkbuf + variable b1

: bb.swap b0 b1 swapvars ;
: bb.clrupd >bb.upd false swap ! ;
: bb.empty dup bb.clrupd >bb.id 0xffff swap ! ;
: bb.save dup bb.clrupd dup >bb.id @ swap >bb.data bwrite ;
: bb.trysave dup >bb.upd @ if bb.save else drop then ;

0 variable blk
create blkstack saved-max cells allot
blkstack value blkstack-top
: bb.pushblk blk @ blkstack-top ! cell +to blkstack-top ;
: bb.popblk  cell negate +to blkstack-top blkstack-top @ blk ! ;

: update b0 @ >bb.upd true swap ! ;
: buffer b1 @ dup bb.trysave tuck >bb.id ! >bb.data ;
: block cond
    dup b0 @ >bb.id @ = if drop else
    dup b1 @ >bb.id @ = if drop bb.swap else
    dup buffer bread bb.swap
  endcond b0 @ >bb.data ;
: save-buffers b0 @ bb.trysave b1 @ bb.trysave ;
: empty-buffers b0 @ bb.empty b1 @ bb.empty ;
: flush save-buffers empty-buffers ;

: load dup blk ! bb.pushblk block 1024 evaluate bb.popblk ;
: thru swap |: 2dup >= if dup load 1+ loop then 2drop ;

\ todo '\' comments
