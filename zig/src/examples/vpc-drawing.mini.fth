\ ===
\
\ WIP drawing app
\
\ ===

: region 4 tags create @0 , @1 , @2 , @3 , ;

\ : region create >r >r >r , r> , r> , r> , ;
: region>stack @+ swap @+ swap @+ swap @ ;

0 variable o.x
0 variable o.y

: >o o.y ! o.x ! ;
: o.reg>stk @+ o.x @ + swap @+ o.y @ + swap @+ o.x @ + swap @ o.y @ + ;

( x y x0 y0 x1 y1 -- t/f )
: inside? [ 4 tags, ] @1 @3 in[,) swap @0 @2 in[,) and ;
\ : inside? >r swap >r rot >r in[,) r> r> r> in[,) and ;

0 variable c.0
1 variable c.1
0 variable c.sel

: c.adv dup @ 1+ 16 mod swap ! ;

: c.toggle c.sel @ 0= c.sel ! ;

: c.current c.sel @ 0= if c.0 else c.1 then ;

 0 0 50 25 region c.view
 1 1 24 24 region c.0.view
\ 26 1 49 24 region c.1.view

: c.draw
  c.view   region>stack 0     prect
  c.0.view region>stack c.0 @ prect
  25 0 >o
  c.0.view o.reg>stk    c.1 @ prect ;

: c.click
  2dup c.0.view region>stack inside? if 2drop c.0 c.adv else
       c.0.view o.reg>stk    inside? if       c.1 c.adv else
  then then ;

( r g b idx -- )
: ppalette! 3 * tuck 2 + pcolors! tuck 1 + pcolors! pcolors! ;

hex
00 00 00 $0 ppalette!
ff ff ff $1 ppalette!
00 00 ff $2 ppalette!
00 ff 00 $3 ppalette!
ff 00 00 $4 ppalette!
00 ff ff $5 ppalette!
ff ff 00 $6 ppalette!
ff 00 ff $7 ppalette!
40 40 40 $8 ppalette!
40 40 a0 $9 ppalette!
40 a0 40 $a ppalette!
a0 40 40 $b ppalette!
40 a0 a0 $c ppalette!
a0 a0 40 $d ppalette!
a0 40 a0 $e ppalette!
a0 a0 a0 $f ppalette!
decimal

0 0 640 400 1 prect

100 100 356 356 0 prect
101 101 355 355 1 prect

: setupbrush 49 0 u>?|: 0 over pbrush! 1+ loop then ;

setupbrush

0 variable mx
0 variable my
0 variable mx-last
0 variable my-last
false variable m0-held

\ : hovered? mx @ my @ rot region>stack inside? ;

: drawline mx @ my @ mx-last @ my-last @ c.current @ pbrushline ;

make on-key 1 = if 'X' = if c.toggle then then ;

make on-mouse-move ( mx my -- ) [ 2 tags, ]
  @0 @1
  mx @ mx-last ! my @ my-last ! my ! mx !
  m0-held @ if drawline
  then ;

( value mods -- )
make on-mouse-down drop dup $7 and 0= if $10 and dup m0-held !
  if mx @ my @ c.click then
  drawline
  else drop then ;

make on-char
  nip emit ;

make frame c.draw ;

main
