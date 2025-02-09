vocabulary blocks
blocks definitions

s[ cell field >id cell field >upd 1024 field >data
]s blkbuf

blkbuf double-buffer blkbufs
: bb.swap blkbufs db.swap ;
: b0 true blkbufs db.get ;
: b1 false blkbufs db.get ;

: clrupd >upd false swap ! ;
: empty dup clrupd >id 0 swap ! ;
: save dup clrupd dup >id @ swap >data bb.write ;
: trysave dup >upd @ over >id @ and if save else drop then ;

forth definitions

0 variable blk

blocks definitions

create blkstack saved-max cells allot
blkstack value blkstack-top
: pushblk blk @ blkstack-top ! cell +to blkstack-top ;
: popblk  cell negate +to blkstack-top blkstack-top @ blk ! ;

forth definitions
blocks

: update b0 >upd true swap ! ;
: buffer b1 dup trysave tuck >id ! >data ;
: block cond
    dup b0 >id @ = if drop else
    dup b1 >id @ = if drop bb.swap else
    dup buffer bb.read bb.swap
  endcond b0 >data ;
: save-buffers b0 trysave b1 trysave ;
: empty-buffers b0 empty b1 empty ;
: flush save-buffers empty-buffers ;

: load pushblk dup blk ! block 1024 evaluate popblk ;
: thru swap |: 2dup >= if dup load 1+ loop then 2drop ;

: bb.this-line 64 / 64 * ;
: bb.next-line 64 + bb.this-line ;

: \ blk @ if >in @ bb.next-line >in ! else [compile] \ then ;

compiler definitions
: \ [compile] \ ;

forth definitions
