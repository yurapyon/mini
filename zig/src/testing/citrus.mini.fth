variable anim-at
0 anim-at !
: .anim
  s" *(oo (oo (oo" cell + anim-at @ 4 * + 4 type
  anim-at @ 1+ 3 mod anim-at ! ;

: time 12 30 59 ;
: .time time drop swap 12 mod dup 0= if drop 12 then . . ;

: bprop ;
: .batt
  s" capacity" bprop .
  s" status" bprop case
    [char] D of ."  " endof
    [char] C of ." +" endof
    [char] F of ." +" endof
    [char] U of ." !" endof
  ." ?"
  endcase ;

: .bar .time space .batt space .anim cr ;

\ : loop .bar 1 sleep recurse ;

\ status-bar stdout !
\ loop
.bar
.bar
.bar
.bar
.bar
