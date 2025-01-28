: .n dup dup dup decimal 3 u.r space hex 2 u.0 space print space space 32 + ;
: .ls 2dup > if dup .n .n .n .n drop cr 1+ recurse then 2drop ;
: ashy base @ >r 32 0 .ls r> base ! ;
