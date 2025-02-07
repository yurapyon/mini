vocabulary blocks
blocks definitions

s[ cell field >id cell field >upd 1024 field >data
]s blkbuf

2 constant blkbuf-ct
create blkbufs blkbuf blkbuf-ct * allot
blkbufs variable b0 blkbufs blkbuf + variable b1

: bswap b0 b1 swapvars ;
: clrupd >upd false swap ! ;
: empty dup clrupd >id 0xffff swap ! ;
: save dup clrupd dup >id @ swap >data bwrite ;
: trysave dup >upd @ if save else drop then ;

forth definitions

0 variable blk

blocks definitions

create blkstack saved-max cells allot
blkstack value blkstack-top
: pushblk blk @ blkstack-top ! cell +to blkstack-top ;
: popblk  cell negate +to blkstack-top blkstack-top @ blk ! ;

forth definitions
blocks

: update b0 @ >upd true swap ! ;
: buffer b1 @ dup trysave tuck >id ! >data ;
: block cond
    dup b0 @ >id @ = if drop else
    dup b1 @ >id @ = if drop bswap else
    dup buffer bread bswap
  endcond b0 @ >data ;
: save-buffers b0 @ trysave b1 @ trysave ;
: empty-buffers b0 @ empty b1 @ empty ;
: flush save-buffers empty-buffers ;

: load dup blk ! pushblk block 1024 evaluate popblk ;
: thru swap |: 2dup >= if dup load 1+ loop then 2drop ;

forth

\ todo '\' comments
