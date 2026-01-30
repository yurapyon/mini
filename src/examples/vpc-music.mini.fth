\ ===
\
\ WIP music thing
\
\ ===

: putchar ( x y c -- ) >r 80 * + 2 * r> swap chars! ;

\ OPL info
\ https://www.shipbrook.net/jeff/sb.html

$16b constant _c#
$181 constant _d
$198 constant _d#
$1b0 constant _e
$1ca constant _f
$1e5 constant _f#
$202 constant _g
$220 constant _g#
$241 constant _a
$263 constant _a#
$287 constant _b
$2ae constant _c

: note ( o f -- n ) swap 10 lshift or ;

s[
  cell field >is-on
  cell field >note
]s voice

create v0 voice allot
false v0 >is-on !

: voice.note
  dup >is-on @ 1 and 13 lshift swap >note @ $1fff and or
  hex
  .s cr
  $a0 over .s cr opl
  $b0 swap 8 rshift .s cr opl decimal ;

make on-char nip cond
  dup 'a' = if true v0 >is-on ! 3 _c note v0 >note ! v0 voice.note then
  dup 's' = if true v0 >is-on ! 4 _d note v0 >note ! v0 voice.note then
  dup 'd' = if true v0 >is-on ! 4 _e note v0 >note ! v0 voice.note then
  dup 'f' = if true v0 >is-on ! 4 _f note v0 >note ! v0 voice.note then
      'v' = if false v0 >is-on !                     v0 voice.note then
  endcond ;

: main true continue ! |: continue @ if
    frame poll! 30 sleep
  loop then ;

$20 $20 opl
$40 $00 opl
$60 $f0 opl
$80 $f7 opl
$c0 $01 opl

main
