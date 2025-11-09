\ ===
\
\ drawing app (WIP)
\
\ click on the palette on the left to select a primary color
\ shift+click ..                   to select a secondary color
\ press 'x' to switch primary and secondary colors
\ press 'e' to open color editor
\
\ ===

( x y c -- )
: putchar >r 80 * + 2 * 16 16 10 * * + r> swap chars! ;

\ ===

7 7 ialloc constant brush

: setupbrush
  49 0 u>?|: dup 7 /mod 0 brush i!xy 1+ loop then 2drop
  3 3 1 brush i!xy ;

: brushline >r >r >r 3 - r> 3 - r> 3 - r> 3 - $f brush blitline ;

setupbrush

\ initial palette ===

hex
00 00 00 0 pal!
ff ff ff 1 pal!
00 00 ff 2 pal!
00 ff 00 3 pal!
ff 00 00 4 pal!
00 ff ff 5 pal!
ff ff 00 6 pal!
ff 00 ff 7 pal!
40 40 40 8 pal!
40 40 a0 9 pal!
40 a0 40 a pal!
a0 40 40 b pal!
40 a0 a0 c pal!
a0 a0 40 d pal!
a0 40 a0 e pal!
a0 a0 a0 f pal!

ff ff ff 0 cpal!
00 00 00 1 cpal!
ff ff ff 2 cpal!
ff ff ff 3 cpal!
ff ff ff 4 cpal!
ff ff ff 5 cpal!
ff ff ff 6 cpal!
ff ff ff 7 cpal!
decimal

\ ===

0 variable offx
0 variable offy

: >off offy ! offx ! ;

: offp >r >r offx @ + r> offy @ + r> putp ;

: offline [ 5 tags, ]
  @0 offx @ + @1 offy @ + @2 offx @ + @3 offy @ + @4
  putline ;

: offrect [ 5 tags, ]
  @0 offx @ + @1 offy @ + @2 offx @ + @3 offy @ + @4
  putrect ;

: offblit [ 4 tags, ] @0 offx @ + @1 offy @ + @2 @3 blit ;

: offchar >r >r offx @ + r> offy @ + r> putchar ;

\ page ===

600 300 ialloc constant stage

0 variable stageoffx
0 variable stageoffy

: setupstage
  1 stage i!fill
  35 stageoffx ! 10 stageoffy !
  ;

: drawstage
  stageoffx @ stageoffy @ >off
  0 0 $ff stage offblit ;

: page
  25 0 640 400 scissor
  0 0 640 400 0 putrect
  drawstage
  unscissor ;

\ color selector ===

0 variable c.pri
1 variable c.sec

: offhex
  16 /mod digit>char 1 0 rot offchar
  16 /mod digit>char 0 0 rot offchar
  drop ;

: values
  32 0 >off 0 0 16 60 0 offrect
  c.pri @ pal@ 4 2 >off offhex 4 1 >off offhex 4 0 >off offhex
  c.sec @ pal@ 4 5 >off offhex 4 4 >off offhex 4 3 >off offhex ;

: hidevalue
  0 0 0 offchar 1 0 0 offchar
  0 1 0 offchar 1 1 0 offchar
  0 2 0 offchar 1 2 0 offchar ;

: hidevalues 4 0 >off hidevalue 4 3 >off hidevalue ;

( n -- )
: slider
  0 0  256 10 0 offrect
    0 over  9 1 offline
  ;

false variable show-sliders

: sliders
  c.pri @ pal@ 48 20 >off slider 48 10 >off slider 48  0 >off slider
  c.sec @ pal@ 48 50 >off slider 48 40 >off slider 48 30 >off slider
  ;

( x y -- )
: slide
  swap 48 - 0 255 clamp swap
  dup 30 >= if 30 - c.sec else c.pri then @ 3 * >r
  10 / r> + p!
  ;

: selbutton >r 0 r@ 25 * >off 2 2 23 23 r> offrect ;

: selector
  0 0 25 400 0 putrect
  0 c.pri @ 25 * >off  0 0 11 25 1 offrect
  0 c.sec @ 25 * >off 15 0 25 25 1 offrect
  0 16 range u>?|: dup selbutton 1+ loop then 2drop
  show-sliders @ if
    values sliders
  then ;

: select ( x y -- c ) nip 25 / ;

: c.toggle c.pri @ c.sec @ c.pri ! c.sec ! selector ;

: s.toggle
  show-sliders @ 0= dup show-sliders !
  if selector else hidevalues page then ;

\ ===

: drawdot swap stageoffx @ - swap stageoffy @ -
  c.pri @ stage i!xy
  drawstage
  ;

: drawline [ 4 tags, ]
  @0 stageoffx @ - @1 stageoffy @ - @2 stageoffx @ - @3 stageoffy @ -
  c.pri @ stage i!line
  drawstage ;

0 variable mx
0 variable my
0 variable mx-last
0 variable my-last
false variable mheld

: mnext mx @ mx-last ! my @ my-last ! my ! mx ! ;

: mpressed? $10 and ;
: shift?    $1 and ;

make on-mouse-move mnext
  mheld @ show-sliders @ 0= and if
    mx-last @ my-last @ mx @ my @ drawline
  then ;

make on-mouse-down
  >r
  mpressed? if
    true mheld !
    mx @ 25 < if
      mx @ my @ select r> shift? if c.sec else c.pri then !
      selector
    else
      show-sliders @ if
        mx @ my @ slide
        selector
      else
        mx @ my @ drawdot
      then
      r> drop
    then
  else
    false mheld !
    r> drop
  then ;

: kpressed? 1 = ;

make on-key kpressed? if cond
    dup 'X' = if drop c.toggle else
    dup 'E' = if drop s.toggle else
      drop
    endcond
  else drop then ;

setupstage
page
selector

." here "
here . cr

main
