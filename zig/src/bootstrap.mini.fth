here constant bootstrap0

vocabulary target
target definitions

8 1024 * allocate constant mem

: t@   mem dyn@ ;
: t!   mem dyn! ;
: t+!  mem dyn+! ;
: tc@  mem dync@ ;
: tc!  mem dync! ;
: tc+! mem dync+! ;
: >t   mem >dyn ;

: .print do.u> dup tc@ print 1+ godo 2drop ;
: .bytes do.u> dup tc@ .byte space 1+ godo 2drop ;
: .mem range do.u> 16 split dup .short space 2dup .bytes .print
  cr godo 2drop ;

: l[ 0 ;
: ]l constant ;
: layout  over constant + ;
: layout- - dup constant ;

\ NOTE
\ cell size of target == cell size of host

l[
   cell layout _pc  \ program counter
   cell layout _cta \ current token addr
   cell layout s*
   cell layout r*
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
   cell layout loop*
2 cells layout execreg
]l internal0

l[
  1024 layout-  b1
  1024 layout-  b0
  dup  constant r0
  64 cells -    \ spacing for rstack
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

: tclone define ['] docre @ , ['] exit , , does> @ t, ;
: tclone,here there -rot tclone ;

0 value docol#
0 value docon#

0 value exit-addr
0 value jump-addr
0 value jump0-addr
0 value lit-addr

: t: word 2dup tclone,here tdefine docol# t, there loop* t! ;
: t; exit-addr t, ;

: tconstant word 2dup tclone,here tdefine docon# t, t, ;

: builtins[ 0 ;
: ]builtins ." builtins ct: " . cr ;
: b:        dup word 2dup tclone,here third , tdefine t, 1+ ;
: 'baddr '  2 cells + @ ;
: 'bcode '  3 cells + @ ;

: t(later), there 0 t, ;
: tthis!    there swap t! ;

: tif   jump0-addr t, t(later), ;
: telse jump-addr t, t(later), swap tthis! ;
: tthen tthis! ;

: tliteral lit-addr t, t, ;

: t|:   there loop* t! ;
: tloop jump-addr t, loop* t@ t, ;

: initexecreg exit-addr execreg cell + t! ;

\ : 0     0 _literal ;
\ : 128   128 _literal ;
\ : false 0 ;
\ : true  0xffff _literal ;

internal0 h t!
0 fvocab t!
0 cvocab t!
fvocab current t!
fvocab context t!

\ todo
\ probably don't need:
\   quit , c,
\ need:
\   u/ u/mod
\   negate

builtins[
  b: exit
  b: docol
  b: docon
  b: docre
  b: jump
  b: jump0
  b: lit
  b: panic
  \ b: abort"
  b: quit
  b: accept
  b: emit
  b: =
  b: >
  b: >=
  b: 0=
  b: <
  b: <=
  b: u>
  b: u>=
  b: u<
  b: u<=
  b: and
  b: or
  b: xor
  b: invert
  b: lshift
  b: rshift
  b: !
  b: +!
  b: @
  b: ,
  b: c!
  b: +c!
  b: c@
  b: c,
  b: >r
  b: r>
  b: r@
  b: +
  b: -
  b: *
  b: /
  b: mod
  b: /mod
  b: */
  b: */mod
  b: 1+
  b: 1-
  b: drop
  b: dup
  b: ?dup
  b: swap
  b: flip
  b: over
  b: nip
  b: tuck
  b: rot
  b: -rot
]builtins

'bcode docol to docol#
'bcode docon to docon#
'baddr exit  to exit-addr
'baddr jump  to jump-addr
'baddr jump0 to jump0-addr
'baddr lit   to lit-addr
initexecreg

bl tconstant bl
source-ptr   tconstant source-ptr
source-len   tconstant source-len
>in          tconstant >in
input-buffer tconstant input-buffer

t: 2dup  over over t;
t: 2drop drop drop t;
t: 2swap >r flip r> flip t;
\ t: 3drop drop 2drop t;
\ t: third >r over r> swap t;
\ t: 3dup  third third third t;

t: <> = 0= t;

t: /string tuck - -rot + swap t;
t: -leading dup tif over c@ bl = tif 1 tliteral /string tloop tthen
   tthen t;
t: range over + swap t;

t: source source-ptr @ ?dup 0= tif input-buffer tthen
  source-len @ t;

t: source@ source drop >in @ + t;
t: next-char source@ c@ 1 tliteral >in +! t;
t: source-rest source@ source + over - t;

t: nextbl t|: 2dup u> tif dup c@ bl <> tif 1+ tloop tthen
   tthen nip t;
t: token -leading 2dup range nextbl nip over - t;
t: word source-rest token 2dup + source drop - >in ! t;

t: execute execreg tliteral ! jump execreg t, t;

0 there .mem
." after compile: " .s cr
." mem size: " there . cr

0 [if]

\ >number
\ lookup
\ on word not found

\ : lit, lit lit , ;
\ : name cell + c@+ ;
\ : >cfa name + aligned ;

t: execute execreg _literal ! jump execreg , t;

t: onlookup 0= state _literal @ and _if >cfa , else >cfa execute _then t;
t: onnumber state _literal @ _if lit, , _then t;

t: resolve
    2dup lookup ?dup _if 2swap 2drop swap onlookup _else
    2dup >number     _if -rot 2drop       onnumber _else
    \ todo
    \ on word not found
  _then _then t;

t: refill,user input-buffer _literal 128 accept source-len _literal ! 0 >in _literal ! t;
t: refill source-ptr _literal @ _if false _else refill,user true _then t;

t: word! word ?dup 0= _if drop refill _if _loop _else
   0 0 _then _then t;

t: interpret word! ?dup _if resolve _loop _else drop _then t;

[then]

forth definitions

0 [if]

\ ===

0 variable state
10 variable base
\ here variable h
\ : here h @ ;
\ : allot h +! ;
\ : , here ! cell allot ;
\ : c, here c! 1 allot ;
\ : aligned dup cell mod + ;
\ : align here aligned h ! ;

compiler definitions
: do.dup [compile] |: ['] dup , [compile] if ;
forth definitions

0 variable source-ptr
0 variable source-len
0 variable >in

create input-buffer 128 allot

: source source-ptr @ ?dup 0= if input-buffer then
  source-len @ ;

\ todo use addr from zig
\ 0 constant input-buffer
: refill,user input-buffer 128 accept source-len ! 0 >in ! ;
: refill source-ptr @ if false else refill,user true then ;

: source@ source drop >in @ + ;
: next-char source@ c@ 1 >in +! ;

: source-rest source@ source + over - ;

: nextbl do.u> dup c@ bl <> if 1+ godo then nip ;
: token -leading 2dup range nextbl nip over - ;
: word source-rest token 2dup + source drop - >in ! ;

( name len start -- addr )
: locate do.dup 3dup name string~= 0= if @ godo then nip nip ;

\ todo need to check it isn't 0 before dereferencing it
\ another thing could be that '0 @' is 0
: locskip 3dup locate dup current @ @ = if drop @ locate else
  >r 3drop r> then ;

: locprev state @ if locskip else locate then ;

: find 2dup context @ @ locprev ?dup if nip nip else
  forth-latest @ locprev then ;

( name len -- compiler-word? addr/0 )
: lookup cond
  2dup compiler-latest @ locprev ?dup if nip nip true swap else
  2dup find ?dup if nip nip false swap else 2drop 0 endcond ;

\ note
\ doesnt work with temporary strings
: str, dup c, tuck here swap move allot ;

: define align here >r current @ @ , str, align r> current @ ! ;

: ' word find dup if >cfa then ;

\ numbers ===

( str len -- t/f )
: negative? drop c@ '-' = ;
: char? 3 = swap dup c@ ''' = swap 2 + c@ ''' = and and ;

( str len -- # )
: >base drop c@ cond dup '%' = if drop 2 else
  dup '#' = if drop 10 else '$' = if 16 else base @ endcond ;
: >char drop 1+ c@ ;

( digit base -- )
: accumulate pad @ * + pad ! ;

( str len base -- number t/f )
: >number,base >r range 0 pad !
  do.u> dup c@ char>digit dup r@ < if r@ accumulate 1+ godo then
  r> drop = if pad @ true else drop false then ;

( str len -- number t/f )
: >number 2dup char? if >char true exit then 2dup negative? -rot
  third if 1 /string then 2dup >base >number,base
  if swap if negate then true else drop false then ;

\ ===

: word! word ?dup 0= if drop refill if loop else 0 0 then then ;

: onlookup 0= state @ and if >cfa , else >cfa execute then ;
: onnumber state @ if lit, , then ;

: resolve cond
    2dup lookup ?dup if 2swap 2drop swap onlookup else
    2dup >number     if -rot 2drop       onnumber else
    type ." ?_" cr
  endcond ;

: interpret word! ?dup if resolve loop else drop then ;

create execreg 0 , ' exit ,

: execute execreg ! jump [ execreg , ] ;

\ ' interpret ,

\ version major , minor ,
\ 0 , 1 ,

bootstrap0 @ dist ./k cr

[then]


\ bootstrapper ===

\ tokenizing
\ states

\ kernel ===

\ @ ! +

\ precompiled ===

\ state
\ h

\ 2dup
\ [ ]
\ : ; define

\ ,
\ if/cond

\ align aligned

\ >cfa
\ execute

\ lookup word
\ >number

\ refill
\ word/tokenizing input

\ variables
\ source management

\ interpret
\ evaluate

\ would be nice to have ===
\ constants
\ field s[ ]s

\ dont think you need ===
\ pad
\ blocks
\ strings
\ extra math stuff
\ comments
