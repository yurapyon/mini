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
  49 0 check> if dup 7 /mod 0 brush i!xy 1+ loop then 2drop
  3 3 1 brush i!xy ;

: brushline >r >r >r 3 - r> 3 - r> 3 - r> 3 - $f brush blitline ;

\ initial palette ===

pdefault
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
decimal

\ ===

0 variable offx
0 variable offy
: >offset offy ! offx ! ;
: offset+ swap offx @ + swap offy @ + ;
: offset2+ >r >r offset+ r> r> offset+ ;

: offline >r offset2+ r> putline ;
: offrect >r offset2+ r> putrect ;
: offblit >r >r offset+ r> r> blit ;

: offchar >r offset+ swap 8 / swap 10 / r> putchar ;

: offtype ( a n -- ) swap >r
  0 check> if dup 0 over 8 * flip r@ + c@ offchar 1+ loop then
  r> 3drop ;

: offhex <# h# h# #> offtype ;

2 cells constant /coord
16 constant #coords
create coords #coords /coord * allot
0 variable coord#
: coord coords coord# @ /coord * + ;
: cclear 0 coord# ! 0 0 >offset ;
: >c     offy @ offx @ coord !+ ! offset+ >offset 1 coord# +! ;
: c>     -1 coord# +! coord @+ swap @ >offset ;

\ canvas ===

0 [if]

s[
  cell field >canvas-id
  cell field >name
]s /layer

<array> constant layers

: add-layer
  600 360 ialloc layers push
  <array> layers push ;

0 variable #layers
allocate0 constant layers

: add-layer
  #layers @ dup 1+ /layer * layers reallocate
  600 360 ialloc swap layers dyn!
  ;

[then]

600 360 ialloc constant canvas

0 variable stagex
0 variable stagey

: setupcanvas
  $ff canvas i!fill
  35 stagex ! 10 stagey !
  ;

: drawstage
  25 0 640 400 scissor
  0 0 640 400 0 putrect
  stagex @ stagey @ >offset
  0 0 600 360 1 offrect
  0 0 $ff canvas offblit
  unscissor ;

\ color selector ===

0 variable c.pri
1 variable c.sec

: e.hide 32 0 >offset
  0  0 0 offchar 8  0 0 offchar
  0 10 0 offchar 8 10 0 offchar
  0 20 0 offchar 8 20 0 offchar ;

: slider >r
  0 0 16 10 0 offrect
  r@ offhex
  16 0 >c
     0 0 256 10 0 offrect
    r@ 0  r@  9 1 offline
  c>
  r> drop ;

: e.draw
  c.pri @ pal@
  cclear
  32 0 >c
    0 20 >c slider c>
    0 10 >c slider c>
    0  0 >c slider c>
  c> ;

( x y -- )
: slide
  dup 30 < if
    swap 48 - 0 255 clamp swap
    10 / c.pri @ 3 * + p!
    e.draw
  else 2drop then ;

: selbutton >r 0 r@ 25 * >offset 2 2 23 23 r> offrect ;

: selector
  0 0 25 400 0 putrect
  0 c.pri @ 25 * >offset  0 0 11 25 1 offrect
  0 c.sec @ 25 * >offset 15 0 25 25 1 offrect
  0 16 range check> if dup selbutton 1+ loop then 2drop ;

: select ( x y -- c ) nip 25 / ;

: c.toggle c.pri @ c.sec @ c.pri ! c.sec ! selector ;

\ ===

: drawdot swap stagex @ - swap stagey @ -
  c.pri @ canvas i!xy
  drawstage
  ;

: drawline [ 4 tags, ]
  @0 stagex @ - @1 stagey @ - @2 stagex @ - @3 stagey @ -
  c.pri @ canvas i!line
  drawstage ;

\ ===

0 variable mx
0 variable my
0 variable mx-last
0 variable my-last
false variable mheld
0 variable mmods

: mnext mx @ mx-last ! my @ my-last ! my ! mx ! ;

: mpressed? $10 and ;
: shift?    $1 and ;
: kpressed? 1 = ;

\ ===

doer mmove
doer mdown
doer e.toggle

: click-colors
  mx @ my @ select mmods @ shift? if c.sec else c.pri then !
  selector ;

defer hide-editor

: show-editor
  make e.toggle hide-editor ;and
  make mmove 
    mx @ 25 > mheld @ and if
      mx @ my @ slide selector e.draw
    then
  ;and
  make mdown
    mx @ 25 < if click-colors e.draw else
      mx @ my @ slide selector e.draw
    then
  ;and
  selector e.draw
  ;

:noname
  make e.toggle show-editor ;and
  make mmove mheld @ if
    mx-last @ my-last @ mx @ my @ drawline
  then ;and
  make mdown
    mx @ 25 < if click-colors else
      mx @ my @ drawdot
    then
  ;and
  selector e.hide drawstage
  ; is hide-editor

\ ===

make on-mouse-move mnext mmove ;

make on-mouse-down mmods ! mpressed? mheld ! mdown ;

make on-key kpressed? if cond
    dup 'X' = if drop c.toggle else
    dup 'E' = if drop e.toggle else
      drop
    endcond
  else drop then ;

setupbrush
setupcanvas
hide-editor

main
