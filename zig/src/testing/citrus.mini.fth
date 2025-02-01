: time 12 30 59 ;
: 24>12 12 mod dup 0= if drop 12 then ;
: bprop ;

\ ===

0 value anim-at

: bar
  time drop swap 24>12 u. [char] : emit u.
  space

  s" capacity" bprop u.
  s" status" bprop case
    [char] D of ."  " endof
    [char] C of ." +" endof
    [char] F of ." +" endof
    [char] U of ." !" endof
  ." ?"
  endcase
  space

  s" *(oo (oo (oo" cell + anim-at 4 * + 4 type
  anim-at 1+ 3 mod to anim-at
  cr

  \ 1 sleep recurse
  ;

bar
