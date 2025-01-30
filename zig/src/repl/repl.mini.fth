32 constant bl
: space bl emit ;
: cr 10 emit ;
: print dup 32 126 within[] 0= if drop [char] . then emit ;
: .print 2dup > if c@+ print recurse then 2drop ;
: .chars 2dup > if c@+ emit recurse then 2drop ;
: type range .chars ;
compiler
: ." [compile] s" ['] count , ['] type , ;
forth
:noname type [char] ? emit cr ; onwnf !

: u. <# #s #> type ;
: u.pad rot <# #s flip #pad #> type ;
: u.r bl u.pad ;
: u.0 [char] 0 u.pad ;
: . u. space ;
: ? @ . ;

: .bytes 2dup > if c@+ 2 u.0 space recurse then 2drop ;
: .lines 2dup > if dup 4 u.r ." : "
    16 split 2dup .bytes .print cr recurse
  then 2drop ;
: dump base @ >r hex range .lines r> base ! ;

: .words ?dup if dup name tuck type if space then @ recurse then ;
: words wlatest .words ;

[defined] block [if]
0 value lct
: linum lct 2 u.r space 1 +to lct ;
: .l 2dup > if 64 split linum .print cr recurse then 2drop ;
: showb base @ >r decimal 0 to lct 1024 range .l r> base ! ;
: list block showb ;

\ editor

: l b0 showb ;
0 value cx
0 value cy
: t 0 to cx to cy b0 cy 64 * + dup 64 + swap .print cy . cr ;
: putc b0 cy 64 * + cx + c! 1 +to cx ;
: readp 2dup > if next-char putc 1+ recurse then 2drop ;
: p next-char source >in @ readp update ;

[then]
