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

: defer create ['] noop , does> @ execute ;
: is    ' >value ! ;

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

: offp >r >r offx @ + r> offy @ + r> putp ;

: offline [ 5 tags, ]
  @0 offx @ + @1 offy @ + @2 offx @ + @3 offy @ + @4
  putline ;

: offrect [ 5 tags, ]
  @0 offx @ + @1 offy @ + @2 offx @ + @3 offy @ + @4
  putrect ;

: offblit [ 4 tags, ] @0 offx @ + @1 offy @ + @2 @3 blit ;

\ todo
\ offchar should div x by 8 and y by 10
: offchar >r >r offx @ + r> offy @ + r> putchar ;

: offhex
  16 /mod digit>char 1 0 rot offchar
  16 /mod digit>char 0 0 rot offchar
  drop ;

2 cells constant /coord
16 constant #coords
create coords #coords /coord * allot
0 variable coord#
: coord coords coord# /coord * + ;
: cclear 0 coord# ! 0 0 >offset ;
: >c     2dup offy +! offx +! swap coord !+ !
         1 coord# +! ;
: c>     coord @+ negate offx +! @ negate offy +!
         -1 coord# +! ;

\ page ===

600 360 ialloc constant canvas

0 variable stagex
0 variable stagey

: setupcanvas
  1 canvas i!fill
  35 stagex ! 10 stagey !
  ;

: drawcanvas
  stagex @ stagey @ >offset
  0 0 $ff canvas offblit ;

: drawstage
  25 0 640 400 scissor
  0 0 640 400 0 putrect
  drawcanvas
  unscissor ;

\ color selector ===

0 variable c.pri
1 variable c.sec

: values
  4 2 >offset offhex
  4 1 >offset offhex
  4 0 >offset offhex
  32 0 >offset 0 0 16 30 0 offrect ;

: hidevalues 4 0 >offset
  0 0 0 offchar 1 0 0 offchar
  0 1 0 offchar 1 1 0 offchar
  0 2 0 offchar 1 2 0 offchar ;

( n -- )
: slider 0 0  256 10 0 offrect 0 over  9 1 offline ;

( n n n -- )
: sliders
  48 20 >offset slider
  48 10 >offset slider
  48  0 >offset slider ;

: e.draw c.pri @ pal@ 3dup values sliders ;

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
  drawcanvas
  ;

: drawline [ 4 tags, ]
  @0 stagex @ - @1 stagey @ - @2 stagex @ - @3 stagey @ -
  c.pri @ canvas i!line
  drawcanvas ;

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
doer ui
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
  make ui    selector e.draw ;and
    ui
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
  make ui    selector hidevalues drawstage ;and
    ui
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
