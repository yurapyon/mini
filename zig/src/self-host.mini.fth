fvocab context ! context @ current !

: \ source-len @ >in ! ;

: cells cell * ;

: forth fvocab context ! ;
: compiler cvocab context ! ;
: definitions context @ current ! ;
compiler definitions
: literal lit, , ;
: [compile] ' , ;
: ['] ' lit, , ;
forth definitions
: constant word define ['] docon @ , , ;
: enum dup constant 1+ ;
: create word define ['] docre @ , ['] exit , ;
: variable create , ;
0 variable loop*
: set-loop here loop* ! ;
compiler definitions
: |: set-loop ;
: loop ['] jump , loop* @ , ;
forth definitions
: : : set-loop ;
: (later), here 0 , ;
: (lit), lit, (later), ;
: this here swap ;
: this! this ! ;
: dist this - ;
compiler definitions
: if ['] jump0 , (later), ;
: else ['] jump , (later), swap this! ;
: then this! ;
forth definitions
: ( next-char ')' = 0= if loop then ;
: last current @ @ >cfa ;
: >does cell + ;
compiler definitions
: does> (lit), ['] last , ['] >does , ['] ! , ['] exit , this!
  ['] docol @ , ;
forth definitions
: value create , does> @ ;
: vname ' 2 cells + ;
: to  vname ! ;
: +to vname +! ;
: vocabulary create 0 , does> context ! ;

: space bl emit ;
: cr    10 emit ;

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
: u.pad rot <# #s flip #pad #> type ;
: u.r bl u.pad ;
: u.0 '0' u.pad ;
: u. <# #s #> type ;
: . u. space ;
: printable 32 126 in[,] ;
: print dup printable 0= if drop '.' then emit ;
: byte. <# h# h# #> type ;
: short. <# h# h# h# h# #> type ;

: print. 2dup u> if c@+ print loop then 2drop ;
: bytes. 2dup u> if c@+ byte. space loop then 2drop ;

: split over + tuck swap ;

: sdata s* @ s0 over - ;
: depth sdata nip cell / ;

: .cells swap cell - |: 2dup <= if dup @ . cell - loop then
  2drop ;
: <.> <# '>' hold #s '<' hold #> type ;
: .s depth <.> space sdata range .cells ;

: println next-char drop source-rest type source-len @ >in ! ;

: hex 16 base ! ;
: decimal 10 base ! ;

vocabulary target
target definitions

create mem 6 1024 * allot

: t@   mem + @ ;
: t!   mem + ! ;
: t+!  mem + +! ;
: tc@  mem + c@ ;
: tc!  mem + c! ;
: t+c! mem + +c! ;
: >t   swap mem + swap move ;

: mem. swap mem + swap range |: 2dup u> if
    16 split dup mem - short. space 2dup bytes. print.
  cr loop then 2drop ;

: l[ 0 ;
: ]l constant ;
: layout  over constant + ;
: layout- - dup constant ;

\ NOTE
\ cell size of target == cell size of host

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
   cell layout fvocab
   cell layout cvocab
   cell layout current
   cell layout context
   cell layout state
   cell layout base
   cell layout source-ptr
   cell layout source-len
   cell layout >in
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

: there  h t@ ;
: tallot h t+! ;
: t,     there t! cell tallot ;
: tc,    there tc! 1 tallot ;
: talign there aligned h t! ;

: tname,  dup tc, tuck there swap >t tallot ;
: tdefine talign there >r current t@ t@ t, tname, talign
  r> current t@ t! ;

: tforth       fvocab context t! ;
: tcompiler    cvocab context t! ;
: tdefinitions context t@ current t! ;

: 'taddr ' 2 cells + @ ;

: tc@+ dup 1+ swap tc@ ;
: tname cell + tc@+ ;
: t>cfa tname + aligned ;
: 'tcfa 'taddr t>cfa ;

: tclone define ['] docre @ , ['] exit , there , does> @ t>cfa t, ;

0 value docol#
0 value docon#

0 value exit-addr
0 value jump-addr
0 value jump0-addr
0 value lit-addr

0 variable loop*

: t: word 2dup tclone tdefine docol# t, there loop* ! ;
: t; exit-addr t, ;

: tconstant word 2dup tclone tdefine docon# t, t, ;

: builtins[ 0 ;
: ]builtins . cr ;
: b:        dup word 2dup tclone third , tdefine t, 1+ ;
: 'bcode '  3 cells + @ ;

: (later), there 0 t, ;
: this!    there swap t! ;

: if   jump0-addr t, (later), ;
: else jump-addr t, (later), swap this! ;
: then this! ;

: literal lit-addr t, t, ;

: |:   there loop* ! ;
: loop jump-addr t, loop* @ t, ;

: >init/exec initxt t! execreg cell + t! ;

\ ===

internal0 h t!
0 fvocab t!
0 cvocab t!
fvocab current t!
fvocab context t!
0    state t!
10   base t!
0    source-ptr t!
true stay t!

\ todo
\ need:
\   u/ u/mod

\ todo abort
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
  b: /mod   b: */     b: */mod b: 1+
  b: 1-     b: negate b: drop  b: dup
  b: ?dup   b: swap   b: flip  b: over
  b: nip    b: tuck   b: rot   b: -rot
  b: move   b: mem=   b: extid
println builtins ct: 
]builtins

'bcode docol to docol#
'bcode docon to docon#
'tcfa exit  to exit-addr
'tcfa jump  to jump-addr
'tcfa jump0 to jump0-addr
'tcfa lit   to lit-addr

32    tconstant bl
2     tconstant cell
0     tconstant false
$FFFF tconstant true
stay         tconstant stay
source-ptr   tconstant source-ptr
source-len   tconstant source-len
>in          tconstant >in
\ todo just use s0 for input buffer
input-buffer tconstant input-buffer
h            tconstant h
current      tconstant current
context      tconstant context
fvocab       tconstant fvocab
cvocab       tconstant cvocab
state        tconstant state
base         tconstant base
s*           tconstant s*
s0           tconstant s0

t: 2dup  over over t;
t: 2drop drop drop t;
t: 3drop drop 2drop t;
t: third >r over r> swap t;
t: 3dup  third third third t;

\ input ===

t: source source-ptr @ ?dup 0= if input-buffer then source-len @ t;

t: source@ source drop >in @ + t;
t: next-char source@ c@ 1 literal >in +! t;
t: source-rest source@ source + over - t;

t: /string tuck - -rot + swap t;
t: -leading dup if over c@ bl = if 1 literal /string loop then then t;
t: range over + swap t;

t: token -leading 2dup range
  |: 2dup u> if dup c@ bl = 0= if 1+ loop then then nip
  nip over - t;

t: word source-rest token 2dup + source drop - >in ! t;

\ lookups ===

t: c@+ dup 1+ swap c@ t;

t: name cell + c@+ t;

t: string= rot over = if mem= else 3drop false then t;

\ skips most recent definition if compiling
\ returns 0 on not found
\ assumes current @ @ doesnt == 0,
\   the logic is convoluted but this is generally true
( name len start -- addr/0 )
t: locate dup current @ @ = context @ current @ = state @ and and if @ then
  |: dup if 3dup name string= 0= if @ loop then then nip nip t;

( name len -- addr/0 )
t: find 2dup context @ @ locate ?dup if nip nip else fvocab @ locate then t;

\ number conversion ===

t: here h @ t;
t: pad here 64 literal + t;

t: str>char 3 literal = >r c@+ ''' literal = >r c@+ swap c@ ''' literal =
  r> r> and and t;

t: str>neg over c@ '-' literal = if 1 literal /string true else false then t;

t: str>base over c@
   dup '%' literal = if drop 1 literal /string  2 literal else
   dup '#' literal = if drop 1 literal /string 10 literal else
       '$' literal = if      1 literal /string 16 literal else
     base @
   then then then t;

t: in[,] rot tuck >= -rot <= and t;

t: char>digit
    dup '0' literal '9' literal in[,] if '0' literal - else
    dup 'A' literal 'Z' literal in[,] if '7' literal - else
    dup 'a' literal 'z' literal in[,] if 'W' literal - else
    drop -1 literal
  then then then t;

t: str>number 0 literal pad ! >r range |: 2dup u> if
    dup c@ char>digit r@ 2dup < if pad @ * + pad ! 1+ loop else 2drop then
  then r> drop = pad @ swap t;

t: >number 2dup str>char if -rot 2drop true exit else drop then
  str>neg >r str>base str>number tuck r> and if negate then swap t;

\ interpret/compile ===

t: allot h +! t;
t: ,  here ! cell allot t;
t: c, here c! 1 literal allot t;
t: lit, lit lit , t;

t: .chars 2dup u> if c@+ emit loop then 2drop t;
t: type range .chars t;

t: execute execreg literal ! jump execreg t, t;

t: aligned dup cell mod + t;
t: align here aligned h ! t;
t: >cfa name + aligned t;

t: refill source-ptr @ if false else
  input-buffer 128 literal accept source-len ! 0 literal >in !
  true then t;

t: word! word ?dup 0= if drop refill if loop else
   0 literal 0 literal then then t;

t: interpret word! ?dup if
    state @ if
      \ skip recent
      2dup cvocab @ locate ?dup if -rot 2drop >cfa execute else
      2dup find            ?dup if -rot 2drop >cfa ,       else
      2dup >number              if -rot 2drop lit, ,       else
        \ todo word not found should abort
        drop type '?' literal emit
      then then then
    else
      \ no skip recent
      2dup find ?dup if -rot 2drop >cfa execute else
      2dup >number   if -rot 2drop              else
        \ todo word not found should abort
        drop type '?' literal emit
      then then
    then
    stay @ if loop then
  else
    drop
  then
  t;

t: bye false stay ! t;

t: define align here >r current @ @ ,
  dup c, tuck here swap move allot
  align r> current @ ! t;

t: external word 2dup extid -rot define , t;

\ extras ===

t: ' word find dup if >cfa then t;

t: ] 1 literal state ! t;
tcompiler tdefinitions
t: [ 0 literal state ! t;
tforth tdefinitions

t: : word define docol# literal , ] t;
tcompiler tdefinitions
t: ; 'tcfa exit literal , [ t;
tforth tdefinitions

\ ===

exit-addr 'tcfa interpret >init/exec

\ ===

0 there mem.
println after compile: 
.s cr
println mem size: 
there . cr

mem there
forth bye
