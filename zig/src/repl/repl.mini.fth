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

: b. <# h# h# #> type ;
: c. <# h# h# h# h# #> type ;
: .bytes 2dup > if c@+ b. space recurse then 2drop ;

: dump range ` 2dup > if 16 split
    dup c. space 2dup .bytes .print cr
  loop` then 2drop ;

: words wlatest ` ?dup if dup name tuck type if space then @ loop` then ;

: line# create 0 , , does> dup @+ swap @ u.r space +! ;

[defined] block [if]
2 line# list#
: .list 2dup > if 64 split 1 list# .print cr recurse then 2drop ;
: showb base @ >r decimal 0 to list# 1024 range .list r> base ! ;
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
