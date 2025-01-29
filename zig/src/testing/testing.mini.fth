\ 0 d0 bwrite

: .l 2dup > if dup c@ print 1+ recurse then 2drop ;
: list block dup 1024 + swap .l cr ;

: bprint >r count blk r> + swap move update ;
