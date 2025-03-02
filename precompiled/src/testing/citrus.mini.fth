: bprop 2drop 100 ;

\ ===

: .batt
  s" capacity" bprop u.
  s" status" bprop cond
    dup 'D' = if drop ."  " else
    dup 'C' = if drop ." +" else
    dup 'F' = if drop ." +" else
    dup 'U' = if drop ." !" else
  drop ." ?"
  endcond ;

0 value anim-at

: .anim anim-at 4 d" *(oo (oo (oo" [] type
  anim-at 1+ 3 mod to anim-at ;

: bar time .time12hm space .batt space .anim cr ;
: main bar 1 sleeps loop ;

