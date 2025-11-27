create axes 0 , 0 , 0 , 0 ,

: deadzone dup abs 128 <= if drop 0 then ;

: >axes swap deadzone swap %g.axis-lx - cells axes + ! ;
: .axes axes @+ . @+ . @+ . @ . ;

make on-gamepad drop cond
  dup %g.axis-lx %g.axis-ry in[,] if >axes else
    2drop
  endcond
  .axes cr
  ;

main
