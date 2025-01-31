: s0 3 d" nulsohstxetxeotenqackbelbs ht lf vt ff cr so si " [] ;
: s1 3 d" dledc1dc2dc3dc4naksynetbcanem subescfs gs rs us " [] ;
: ascii cond dup 16 < if s0 type else dup 32 < if 16 - s1 type
  else dup 127 < if emit else drop ." del" endcond ;
: next dup dup dup 3 u.r space b. space ascii space space 32 + ;
: ashy 32 0 ` 2dup > if dup next next next next cr drop 1+ loop`
  then 2drop ;
