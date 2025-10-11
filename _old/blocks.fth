\ blocks ===

\ t: bswap  bswapped @ invert bswapped ! t;
\ t: bfront bswapped @ if b0 else b1 then t;
\ t: bback  bswapped @ if b1 else b0 then t;

\ t: b>id  2 literal cells - t;
\ t: b>upd cell - t;

\ t: bclrupd  b>upd false swap ! t;
\ t: bempty   dup bclrupd b>id 0 literal swap ! t;
\ t: bsave    dup bclrupd dup b>id @ swap bwrite t;
\ t: btrysave dup b>upd @ over b>id @ and if bsave else drop then t;

\ t: update bfront b>upd true swap ! t;
\ t: buffer bback tuck b>id ! t;
\ t: block
\    dup bfront b>id @ = if drop else
\    dup bback  b>id @ = if drop bswap else
\    bback btrysave dup buffer bread bswap
\  then then bfront t;
\ t: save-buffers bfront btrysave bback btrysave t;
\ t: empty-buffers bfront bempty bback bempty t;
\ t: flush save-buffers empty-buffers t;

\ todo
\   blk stack is not really needed if
\   if the max depth of loading a block is 2
\ t: bpushblk blk @ saved-blk* @ ! cell saved-blk* +! t;
\ t: bpopblk  cell negate saved-blk* +! saved-blk* @ @ blk ! t;

\ t: load bpushblk blk @ over blk !
\   if bback btrysave dup buffer tuck bread else block then
\   1024 literal evaluate bpopblk t;

