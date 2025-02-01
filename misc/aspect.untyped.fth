\ needs untyped

: sqrt 0.5 fpow ;

1. fvalue wratio
1. fvalue hratio

\ assume wratio > hratio
: aspect fto hratio fto wratio ;

: wh ( pixel-ct -- w h )
  wratio f* hratio f/ sqrt
  fdup hratio f* wratio f/ ;

: k 1024. f* ;

: .wh
  fdup f.
  k wh fswap f>s . ." x " f>s . cr ;

: .common
  ." 1x" cr
  16.  space .wh
  32.  space .wh
  64.  space .wh
  128. .wh
  256. .wh
  cr
  ." 3x" cr
  16.  3. f* space .wh
  32.  3. f* space .wh
  64.  3. f* .wh
  128. 3. f* .wh
  256. 3. f* .wh
  cr
  ." hratio" cr
  16.  hratio f* .wh
  32.  hratio f* .wh
  64.  hratio f* .wh
  128. hratio f* .wh
  256. hratio f* .wh
  ;
