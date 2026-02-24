\ ===
\
\ WIP music thing
\
\ ===

65  enum %ka
    enum %kb
    enum %kc
    enum %kd
    enum %ke
    enum %kf
    enum %kg
    enum %kh
    enum %ki
    enum %kj
    enum %kk
    enum %kl
    enum %km
    enum %kn
    enum %ko
    enum %kp
    enum %kq
    enum %kr
    enum %ks
    enum %kt
    enum %ku
    enum %kv
    enum %kw
    enum %kx
    enum %ky
constant %kz

\ OPL info
\ https://www.shipbrook.net/jeff/sb.html

0 constant off
1 constant on

create freqs
\ c      c#     d      d#     e      f
  $157 , $16b , $181 , $198 , $1b0 , $1ca ,
\ f#     g      g#     a      a#     b
  $1e5 , $202 , $220 , $241 , $263 , $287 ,
\ c
\ $2ae ,

: note ( o n -- n ) cells freqs + @ swap 10 lshift or ;

s[
  cell field >is-on
  cell field >adsr
  cell field >note
]s voice

create v0 voice allot
false v0 >is-on !

: voice.note
  dup >is-on @ 1 and 13 lshift swap >note @ $1fff and or
  \ todo acct for voice index
  $a0 over opl
  $b0 swap 8 rshift opl ;

4 value oct

: key>note cond
  dup %kz = if oct  0 else
  dup %ks = if oct  1 else
  dup %kx = if oct  2 else
  dup %kd = if oct  3 else
  dup %kc = if oct  4 else
  dup %kv = if oct  5 else
  dup %kg = if oct  6 else
  dup %kb = if oct  7 else
  dup %kh = if oct  8 else
  dup %kn = if oct  9 else
  dup %kj = if oct 10 else
  dup %km = if oct 11 else
    4 0
  endcond note nip ;

create held-keys 32 allot
0 variable #held-keys

: hk.depth #held-keys @ ;
: hk.top held-keys #held-keys @ 1- cells + @ ;
: hk.push
  held-keys #held-keys @ cells + !
  1 #held-keys +!
  ;

: hk.find ( key -- idx/0 t/f )
  >r
  hk.depth 0 check> if
    dup cells held-keys + @ r@ = if
      nip r> drop true exit
    else
      1+ loop
    then
  then r> 3drop 0 false ;

\ todo check depth maybe
: hk.remove ( idx -- )
  dup 1+ cells held-keys +
  over cells held-keys +
  rot hk.depth swap - 1-
  move
  -1 #held-keys +! ;

: hk.play hk.depth 0 >
  dup if hk.top key>note v0 >note ! then
  v0 >is-on ! v0 voice.note ;

\ : hk.play
  \ hk.depth . cr
  \ held-keys 32 dump cr ;

make on-key cond
  dup 0= if drop hk.find if hk.remove hk.play else drop then else
  dup 1 = if drop cond
    dup %kq = if drop -1 +to oct oct . cr else
    dup %kw = if drop  1 +to oct oct . cr else
      hk.push hk.play
    endcond
  else
    2drop
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

0 [if]

: build here >r execute r> ;

0   enum %wait
    enum %call
    enum %note-off
constant %note-on

: note-on %note-on , , ;
: call %call , , ;
: wait %wait , , ;

: strum3 flip note-on 4 wait note-on 4 wait note-on ;

: wawa $ab $cd $ef strum3 ;

: haha ['] wawa call 2 wait ['] wawa call ;

' wawa build
' haha build drop

64 dump


bye

: _ 1 beats wait ;

: ~ 1 qbeats wait ;

: c4 ( set a note ) ;

: thingy
  1 2 3
  ['] wawa spawn
  8 wait
  ['] wawa spawn ;

' thingy spawn

\ spawn saves sp for thread
\ wait
\   looks at top level sp
\   copies sys stack to thread stack
\   tells sched how long to wait
\   save pc probably
\   save rstack
\   return control to scheduler

: wahoo
  [: c4 wawa ;] spawn 1 beats until
  [: e4 wawa ;] spawn 1 beats until
  [: c4 wawa ;] spawn 1 beats until
  [: g4 wawa ;] spawn 1 beats until ;

: a1
  c4
  _ _ _ _
  d4
  _ _ _ _
  ;

: as
  ' a0 spawn
  ' a1 spawn
  join ;

: other

:as2
  ' as spawn
  ' other spawn
  join ;

: song
  as2
  as
  as
  as
  ;

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
  cell field >adsr
  cell field >note
]s voice

create v0 voice allot
false v0 >is-on !

: voice.note
  dup >is-on @ 1 and 13 lshift swap >note @ $1fff and or
  hex
  $a0 over opl
  $b0 swap 8 rshift opl decimal ;

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

: x
 strum
 pause
 pause
 pause
 strum
 pause
 pause
 pause
 ;

main

[then]
