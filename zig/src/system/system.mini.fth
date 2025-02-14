\ : run mark open-file interpret reset ;


\ create current-file 2048 allot

\ : ekey ;

\ : eloop key ekey recurse ;

\ eloop

\ graphics

\ think of sriptes as 1d arrays of colors
\ : put-sprite ( addr len wrap-span -- )
\ len is technically w*h, wrap-span is w

hex
 0  0  0 0 palette
05 05 08 1 palette
decimal

0 0 0 pixel
0 1 0 pixel
0 2 0 pixel
0 3 0 pixel
0 4 0 pixel
0 5 0 pixel
v-up

0 value counter
0 value swp

: drw >r
  10000 0 |: 2dup > if
    dup counter +
    swp 1 and swap r@ pixel
  1+ loop then 2drop
  r> drop ;

: __frame
  0 drw
  1 drw
  2 drw
  v-up
  1 +to swp
  10000 +to counter ;
