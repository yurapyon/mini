: \ source-len @ >in ! ;

\ NOTE
\ Max line length in this file is 80 chars

\ Interpreter starts with forth as the only wordlist in the context

\ system ===

: context     wordlists #order @ 1- cells + ;
: push-order  1 #order +! context ! ;
: also        context @ push-order ;
: previous    -1 #order +! ;

: forth fvocab context ! ;
: compiler cvocab context ! ;
: definitions context @ current ! ;

also compiler definitions
: literal lit, , ;
: [compile] ' , ;
: ['] ' lit, , ;
previous definitions

: constant word define ['] docon @ , , ;
: enum dup constant 1+ ;
: create word define ['] docre @ , ['] exit , ;
: variable create , ;

0 variable loop*
: set-loop here loop* ! ;
also compiler definitions
: |: set-loop ;
: loop ['] jump , loop* @ , ;
previous definitions
: : : set-loop ;

: (later), here 0 , ;
: (lit), lit, (later), ;
: this here swap ;
: this! this ! ;

also compiler definitions
: if   ['] jump0 , (later), ;
: else ['] jump , (later), swap this! ;
: then this! ;

: check> [compile] |: ['] 2dup , ['] u> , ;
previous definitions

: last current @ @ >cfa ;
: >does cell + ;
also compiler definitions
: does> (lit), ['] last , ['] >does , ['] ! , ['] exit , this! ['] docol @ , ;
previous definitions

: value create , does> @ ;
: vname ' 2 cells + ;
: to  vname ! ;
: +to vname +! ;

: vocabulary create 0 , does> context ! ;

: space bl emit ;
: cr    10 emit ;
: type range check> if c@+ emit loop then 2drop ;
: _wnf type '?' emit cr abort ;
' _wnf wnf !

: digit>char dup 10 < if '0' else 'W' then + ;

0 variable #start
: #len pad #start @ - ;
: <# pad #start ! ;
: #> drop #start @ #len ;
: hold -1 #start +! #start @ c! ;
: # base @ /mod digit>char hold ;
: #s dup 0= if # else |: # dup if loop then then ;
: #pad dup #len > if over hold loop then 2drop ;
: h# 16 /mod digit>char hold ;

: u. <# #s #> type ;
: .  u. space ;

: printable 32 126 in[,] ;
: print dup printable 0= if drop '.' then emit ;
: .byte <# h# h# #> type ;
: .short <# h# h# h# h# #> type ;

: .print 2dup u> if c@+ print loop then 2drop ;
: .bytes 2dup u> if c@+ .byte space loop then 2drop ;

: split over + tuck swap ;

: .cells swap cell - check> 0= if dup @ . cell - loop then 2drop ;

: sdata s* @ s0 over - ;
: depth sdata nip cell / ;
: .s    depth '<' emit u. '>' emit space sdata range .cells ;

: println next-char drop source-rest type source-len @ >in ! ;

: c!+   tuck c! 1+ ;
: fill  >r range check> if r@ swap c!+ loop then 2drop r> drop ;
: erase 0 fill ;

: third >r over r> swap ;

: alias create ' , does> @ execute ;

\ metacompiler ===

create mem 6 1024 * allot

: .mem swap mem + swap range check> if
    16 split dup mem - .short space 2dup .bytes .print
  cr loop then 2drop ;

: l[      0 ;
: ]l      constant ;
: layout  over constant + ;
: layout- - dup constant ;

: builtins[ 0 ;
: ]builtins . cr ;
: 'bcode    ' 3 cells + @ ;

vocabulary target
also target definitions

: f@ @ ;
: f! ! ;
: f, , ;

: @   mem + @ ;
: !   mem + ! ;
: +!  mem + +! ;
: c@  mem + c@ ;
: c!  mem + c! ;
: +c! mem + +c! ;
: >t  swap mem + swap move ;

l[
\ kernel internal
    cell layout _pc  \ program counter
    cell layout _cta \ current token addr
    cell layout s*
    cell layout r*
 2 cells layout execreg
    cell layout initxt
\ controlled by forth
    cell layout stay
    cell layout h
    \ todo could rename to forth-worldlist, compiler-wordlist
    cell layout fvocab
    cell layout cvocab
    cell layout current
    cell layout #order
16 cells layout wordlists
    cell layout state
    cell layout base
    cell layout source-ptr
    cell layout source-len
    cell layout >in
    \ todo could rename to on-wnf
    cell layout wnf
    cell layout on-quit
]l internal0

l[
  \ NOTE
  \ r0 can't end at mem = 65536 or address ranges don't work
  cell layout-  _space
  dup  constant r0
  64 cells -    \ spacing for rstack
  \ todo just use s0 for input buffer
  128  layout-  input-buffer
]l s0

: here  h @ ;
: allot h +! ;
: ,     here ! cell allot ;
: c,    here c! 1 allot ;
: align here aligned h ! ;
: (later), here 0 , ;
: this!    here swap ! ;

also forth definitions
: there [ target ] here ;
previous definitions

: c@+ dup 1+ swap c@ ;
: name cell + c@+ ;
: >cfa name + aligned ;
: ' ' 2 cells + f@ >cfa ;

: clone define ['] docre f@ f, ['] exit f, here f, does> f@ >cfa , ;

0 value docol#
0 value docon#

0 value exit-addr
0 value jump-addr
0 value jump0-addr
0 value lit-addr

0 variable loop*
: |:   here loop* f! ;
: loop jump-addr , loop* f@ , ;

: if   jump0-addr , (later), ;
: else jump-addr , (later), swap this! ;
: then this! ;

: literal lit-addr , , ;
: litjump jump-addr , , ;

: context       wordlists #order @ 1- cells + ;
: t.forth       fvocab context ! ;
: t.compiler    cvocab context ! ;
: t.definitions context @ current ! ;

: >sysinit
  initxt !
  execreg cell + !
  wnf !
  on-quit ! ;

\ defining words ===

: name,  dup c, tuck here swap >t allot ;
: define align here >r current @ @ , name, align r> current @ ! ;

: b: dup word 2dup clone third f, define , 1+ ;

: constant word 2dup clone define docon# , , ;

: t: word 2dup clone define docol# , here loop* f! ;
: t; exit-addr , ;

alias : t:
alias ; t;

\ compile image ===

mem internal0 erase
internal0 h !
1 #order !
0 fvocab !
0 cvocab !
fvocab current !
fvocab context !
0    state !
10   base !
0    source-ptr !
true stay !

\ todo
\   u/mod u*/ u*/mod

builtins[
  b: exit   b: docol  b: docon b: docre
  b: jump   b: jump0  b: lit   b: panic
  b: accept b: emit   b: =     b: >
  b: >=     b: 0=     b: <     b: <=
  b: u>     b: u>=    b: u<    b: u<=
  b: and    b: or     b: xor   b: invert
  b: lshift b: rshift b: !     b: +!
  b: @      b: c!     b: +c!   b: c@
  b: >r     b: r>     b: r@    b: +
  b: -      b: *      b: /     b: mod
  b: /mod   b: */     b: */mod b: u/
  b: umod   b: 1+     b: 1-    b: negate
  b: drop   b: dup    b: ?dup  b: swap
  b: flip   b: over   b: nip   b: tuck
  b: rot    b: -rot   b: move  b: mem=
  b: quit   b: extid
println builtins ct: 
]builtins

'bcode docol to docol#
'bcode docon to docon#
' exit  to exit-addr
' jump  to jump-addr
' jump0 to jump0-addr
' lit   to lit-addr

32    constant bl
2     constant cell
0     constant false
$FFFF constant true
$FFFF constant eof
stay         constant stay
source-ptr   constant source-ptr
source-len   constant source-len
>in          constant >in
input-buffer constant input-buffer
h            constant h
current      constant current
#order       constant #order
wordlists    constant wordlists
fvocab       constant fvocab
cvocab       constant cvocab
state        constant state
base         constant base
s*           constant s*
s0           constant s0
r*           constant r*
r0           constant r0
wnf          constant wnf
on-quit      constant on-quit

: 2dup  over over ;
: 2drop drop drop ;
: 3dup  >r 2dup r@ -rot r> ;
: 3drop 2drop drop ;
: cells cell * ;

\ input ===

: source source-ptr @ ?dup 0= if input-buffer then source-len @ ;

: source@     source drop >in @ + ;
: next-char   source@ c@ 1 literal >in +! ;
: source-rest source@ source + over - ;

: 1/string 1- swap 1+ swap ;
: -leading dup if over c@ bl = if 1/string loop then then ;
: range    over + swap ;

: token -leading 2dup range
  |: 2dup u> if dup c@ bl = 0= if 1+ loop then then nip
  nip over - ;

: word source-rest token 2dup + source drop - >in ! ;

\ lookups ===

: c@+     dup 1+ swap c@ ;
: name    cell + c@+ ;
: string= rot over = if mem= else drop 2drop false then ;
: locate  dup if 3dup name string= 0= if @ loop then then nip nip ;
: skip    dup current @ @ = if @ then ;
: (find)  >r #order @ |: dup 0 literal > if
    3dup 1- cells wordlists + @ @ r@ if skip then locate ?dup 0= if 1- loop then
  else 0 literal then r> drop >r 3drop r> ;

\ number conversion ===

: here h @ ;
: pad  here 64 literal + ;

: str>char 3 literal = >r c@+ ''' literal = >r c@+ swap c@ ''' literal =
  r> r> and and ;

: str>neg over c@ '-' literal = if 1/string true else false then ;

: str>base over c@
   dup '%' literal = if drop 1/string  2 literal else
   dup '#' literal = if drop 1/string 10 literal else
       '$' literal = if      1/string 16 literal else
     base @
   then then then ;

: in[,] rot tuck >= -rot <= and ;

: char>digit
    dup '0' literal '9' literal in[,] if '0' literal - else
    dup 'A' literal 'Z' literal in[,] if '7' literal - else
    dup 'a' literal 'z' literal in[,] if 'W' literal - else
    drop -1 literal
  then then then ;

: str>number 0 literal pad ! >r range |: 2dup u> if
    dup c@ char>digit r@ 2dup u< if pad @ * + pad ! 1+ loop else 2drop then
  then r> drop = pad @ swap ;

: >number 2dup str>char if -rot 2drop true exit else drop then
  str>neg >r str>base str>number tuck r> and if negate then swap ;

\ interpret/compile ===

: allot   h +! ;
: ,       here ! cell allot ;
: c,      here c! 1 literal allot ;
: lit,    lit lit , ;
: aligned dup cell mod + ;
: align   here aligned h ! ;
: >cfa    name + aligned ;

: execute execreg literal ! execreg litjump ;

: refill
  source-ptr @ if false else
    input-buffer 128 literal accept
    dup eof = if drop false else source-len ! 0 literal >in ! true then
  then ;

: word! word ?dup 0= if drop refill if loop else
   0 literal 0 literal then then ;

: interpret word! ?dup if
    state @ if
      2dup cvocab @ skip locate ?dup if -rot 2drop >cfa execute else
      2dup true (find) ?dup          if -rot 2drop >cfa , else
      2dup >number                   if -rot 2drop lit, , else
        drop 0 literal state ! align wnf @ execute
      then then then
    else
      2dup false (find) ?dup if -rot 2drop >cfa execute else
      2dup >number           if -rot 2drop              else
        drop wnf @ execute
      then then
    then
    stay @ if loop then
  else
    drop
  then ;

: (quit) on-quit @ execute
  0 literal source-ptr ! source-len @ >in ! interpret ;

: abort s0 s* ! quit ;
: bye false stay ! ;

: define align here >r current @ @ ,
  dup c, tuck here swap move allot
  align r> current @ ! ;

' exit
' 2drop
exit-addr
' (quit)
>sysinit

\ extras ===

: find false (find) ;

: ] 1 literal state ! ;
t.compiler t.definitions
: [ 0 literal state ! ;
t.forth t.definitions

t: : word define docol# literal , ] t;
t.compiler t.definitions
t: ; ' exit literal , [ t;
t.forth t.definitions

t: ' word find dup if >cfa then t;

\ ===

forth

0 there .mem
println after compile: 
.s cr
println mem size: 
there . cr

mem there
bye
