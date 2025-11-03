: in[]c >r |: 2dup > if dup c@ r@ <> if 1+ loop then then
  r> drop <> ;

: instr -rot range rot cin[] ;

: str s" asdfghjkl" ;
