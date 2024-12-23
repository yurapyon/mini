: .next
  dup
  dup decimal 3 u.r space
  dup hex 3 u.r space
      >printable emit
      ."  | "
  32 + ;

: .lines
  2dup > if
    dup ." | " .next .next .next .next drop cr 1+ recurse
  then 2drop ;

: ashy
  base @ >r
  ." | dec hex _ | dec hex _ | dec hex _ | dec hex _ |" cr
  ." |-----------|-----------|-----------|-----------|" cr
  32 0 .lines
  r> base ! ;
