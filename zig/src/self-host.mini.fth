fvocab context ! context @ current !

: \ source-len @ >in ! ;

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

3 cells constant saved-source

l[
\ kernel internal
   cell layout _pc  \ program counter
   cell layout _cta \ current token addr
   cell layout s*
   cell layout r*
2 cells layout execreg
\ controlled by forth
   cell layout stay
   cell layout h
   cell layout fvocab
   cell layout cvocab
   cell layout current
   cell layout context
   cell layout state
   cell layout base
   cell layout bswapped
   cell layout source-ptr
   cell layout source-len
   cell layout >in
   cell layout saved*
8 saved-source *
        layout saved-stack
   cell layout blk
   cell layout saved-blk*
8 cells layout saved-blk-stack
]l internal0

l[
  \ NOTE
  \ b1 can't end at mem = 65536 or address ranges don't work
  cell layout-  _space
  1024 layout-  b1
  cell layout-  b1.upd
  cell layout-  b1.id
  1024 layout-  b0
  cell layout-  b0.upd
  cell layout-  b0.id
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

: savemem word >r >r mem there r> r> >file ;

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

: setexecreg execreg t! exit-addr execreg cell + t! ;

internal0 h t!
0 fvocab t!
0 cvocab t!
fvocab current t!
fvocab context t!
0     state t!
10    base t!
0     source-ptr t!
false bswapped t!
true  stay t!
0     blk t!
saved-stack saved* t!
saved-blk-stack saved-blk* t!

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
  b: move   b: mem=   b: bread b: bwrite
  b: >file
println builtins ct: 
]builtins

'bcode docol to docol#
'bcode docon to docon#
'tcfa exit  to exit-addr
'tcfa jump  to jump-addr
'tcfa jump0 to jump0-addr
'tcfa lit   to lit-addr

bl           tconstant bl
stay         tconstant stay
source-ptr   tconstant source-ptr
source-len   tconstant source-len
>in          tconstant >in
input-buffer tconstant input-buffer
h            tconstant h
current      tconstant current
context      tconstant context
fvocab       tconstant fvocab
cvocab       tconstant cvocab
state        tconstant state
base         tconstant base
0            tconstant false
hex FFFF decimal
             tconstant true
cell         tconstant cell
b0           tconstant b0
b1           tconstant b1
bswapped     tconstant bswapped
saved*       tconstant saved*
blk          tconstant blk
saved-blk*   tconstant saved-blk*
s*           tconstant s*
s0           tconstant s0

t: cells cell * t;

t: 2dup  over over t;
t: 2drop drop drop t;
t: 2swap >r flip r> flip t;
t: 3drop drop 2drop t;
t: third >r over r> swap t;
t: 3dup  third third third t;

t: here    h @ t;
t: allot   h +! t;
t: aligned dup cell mod + t;
t: align   here aligned h ! t;

t: ,  here ! cell allot t;
t: c, here c! 1 literal allot t;

t: c@+ dup 1+ swap c@ t;
t: name cell + c@+ t;

t: >cfa name + aligned t;
t: lit, lit lit , t;

t: /string tuck - -rot + swap t;
t: -leading dup if over c@ bl = if 1 literal /string loop then then t;
t: range over + swap t;

t: .chars 2dup u> if c@+ emit loop then 2drop t;
t: type range .chars t;

t: string= rot over = if mem= else 3drop false then t;

\ ===

t: source source-ptr @ ?dup 0= if input-buffer then source-len @ t;

t: source@ source drop >in @ + t;
t: next-char source@ c@ 1 literal >in +! t;
t: source-rest source@ source + over - t;

t: nextbl |: 2dup u> if dup c@ bl = 0= if 1+ loop then then nip t;
t: token  -leading 2dup range nextbl nip over - t;
t: word   source-rest token 2dup + source drop - >in ! t;

\ t: println next-char drop source-rest type source-len @ >in ! t;

\ ===

( name len start -- addr )
t: locate |: dup if 3dup name string= 0= if @ loop then then nip nip t;

\ todo need to check it isn't 0 before dereferencing it
\ another thing could be that '0 @' is 0
t: locskip 3dup locate dup current @ @ = if drop @ locate else
   >r 3drop r> then t;

t: locprev state @ if locskip else locate then t;

t: find 2dup context @ @ locprev ?dup if nip nip else
  fvocab @ locprev then t;

\ NOTE todo
\ there is a bug where compiler words are being found and executed
\   while in interpreter mode

( name len -- compiler-word? addr/0 )
t: lookup
   2dup cvocab @ locprev ?dup if nip nip true swap else
   2dup find ?dup if nip nip false swap else 2drop 0 literal
   then then t;

t: ' word find dup if >cfa then t;

\ ===

t: negative? drop c@ '-' literal = t;
t: char? 3 literal = swap dup c@ ''' literal = swap
   2 literal + c@ ''' literal = and and t;

( str len -- # t/f )
t: >base drop c@
   dup '%' literal = if drop  2 literal true else
   dup '#' literal = if drop 10 literal true else
       '$' literal = if      16 literal true else
       base @ false
   then then then t;
t: >char drop 1+ c@ t;

t: pad here 64 literal + t;

( digit base -- )
t: accumulate pad @ * + pad ! t;

t: in[,] rot tuck >= -rot <= and t;

t: char>digit
    dup '0' literal '9' literal in[,] if '0' literal - else
    dup 'A' literal 'Z' literal in[,] if '7' literal - else
    dup 'a' literal 'z' literal in[,] if 'W' literal - else
  then then then t;

( str len base -- number t/f )
t: >number,base
   >r range 0 literal pad !
   |: 2dup u> if dup c@ char>digit dup r@ < if r@ accumulate 1+ loop then then
   r> drop = if pad @ true else drop false then t;

\ ( str len -- number t/f )
t: >number 2dup char? if >char true exit then 2dup negative? -rot
   third if 1 literal /string then 2dup >base if >r 1 literal /string r> then
   >number,base if swap if negate then true else drop false then t;

\ ===

t: execute execreg literal ! jump execreg t, t;

\ note todo
\ there is an edge case here
\ if compiler word and not compiling, just compiles the cfa
t: onlookup 0= state @ and if >cfa , else >cfa execute then t;
t: onnumber state @ if lit, , then t;

t: resolve
    2dup
      \ todo kinda messy
      state @ if
        lookup ?dup if 2swap 2drop swap onlookup exit then
      else
        find ?dup if nip nip >cfa execute exit then
      then
    2dup >number     if -rot 2drop       onnumber else
    type '?' literal emit
  then t;

t: refill,user input-buffer 128 literal accept source-len ! 0 literal >in ! t;
t: refill source-ptr @ if false else refill,user true then t;

t: word! word ?dup 0= if drop refill if loop else
   0 literal 0 literal then then t;

t: space bl emit t;
t: cr    10 literal emit t;

\ t: count c@+ t;

\ there s" ( mini )" tstr, talign
t: banner \ literal count type cr t;
  '(' literal emit space
  'm' literal emit 'i' literal emit 'n' literal emit 'i' literal emit space
  ')' literal emit cr t;

\ todo word not found should abort
t: interpret word! ?dup if resolve stay @ if loop then else drop then t;
t: bye false stay ! t;

t: str, dup c, tuck here swap move allot t;
t: define align here >r current @ @ , str, align r> current @ ! t;

t: external word define , t;

t: ss>ptr t;
t: ss>len cell + t;
t: ss>>in 2 literal cells + t;

t: save-source
  source-ptr @ saved* @ ss>ptr !
  source-len @ saved* @ ss>len !
  >in @        saved* @ ss>>in !
  saved-source literal saved* +! t;

t: restore-source
  saved-source literal negate saved* +!
  saved* @ ss>ptr @ source-ptr !
  saved* @ ss>len @ source-len !
  saved* @ ss>>in @ >in ! t;

t: set-source source-len ! source-ptr ! 0 literal >in ! t;

t: evaluate save-source set-source interpret restore-source t;

\ blocks ===

t: bswap  bswapped @ invert bswapped ! t;
t: bfront bswapped @ if b0 else b1 then t;
t: bback  bswapped @ if b1 else b0 then t;

t: b>id  2 literal cells - t;
t: b>upd cell - t;

t: bclrupd  b>upd false swap ! t;
t: bempty   dup bclrupd b>id 0 literal swap ! t;
t: bsave    dup bclrupd dup b>id @ swap bwrite t;
t: btrysave dup b>upd @ over b>id @ and if bsave else drop then t;

t: update bfront b>upd true swap ! t;
t: buffer bback tuck b>id ! t;
t: block
    dup bfront b>id @ = if drop else
    dup bback  b>id @ = if drop bswap else
    bback btrysave dup buffer bread bswap
  then then bfront t;
t: save-buffers bfront btrysave bback btrysave t;
t: empty-buffers bfront bempty bback bempty t;
t: flush save-buffers empty-buffers t;

\ todo
\   blk stack is not really needed if
\   if the max depth of loading a block is 2
t: bpushblk blk @ saved-blk* @ ! cell saved-blk* +! t;
t: bpopblk  cell negate saved-blk* +! saved-blk* @ @ blk ! t;

t: load bpushblk blk @ over blk !
  if bback btrysave dup buffer tuck bread else block then
  1024 literal evaluate bpopblk t;

\ ===

t: ] 1 literal state ! t;
tcompiler tdefinitions
t: [ 0 literal state ! t;
tforth tdefinitions

t: : word define docol# literal , ] t;
tcompiler tdefinitions
t: ; 'tcfa exit literal , [ t;
tforth tdefinitions

\ ===

t: init empty-buffers banner interpret t;

'tcfa init setexecreg

\ ===

forth
: cr cr ;

target

0 there mem.
println after compile: 
.s cr
println mem size: 
there . cr
println saving
savemem mini-out/precompiled.mini.bin cr

forth bye
