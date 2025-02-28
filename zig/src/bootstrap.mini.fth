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
2 cells layout execreg
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
: 'taddr '  2 cells + @ ;

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
  b: negate
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
'taddr exit  to exit-addr
'taddr jump  to jump-addr
'taddr jump0 to jump0-addr
'taddr lit   to lit-addr
initexecreg

bl tconstant bl
source-ptr   tconstant source-ptr
source-len   tconstant source-len
>in          tconstant >in
input-buffer tconstant input-buffer
h tconstant h
current tconstant current
context tconstant context
fvocab tconstant fvocab
cvocab tconstant cvocab
state tconstant state
base  tconstant base
0      tconstant false
0xFFFF tconstant true
cell   tconstant cell

t: 2dup  over over t;
t: 2drop drop drop t;
t: 2swap >r flip r> flip t;
t: 3drop drop 2drop t;
t: third >r over r> swap t;
t: 3dup  third third third t;

t: here h @ t;
t: aligned dup cell mod + t;

\ ===

t: /string tuck - -rot + swap t;
t: -leading dup tif over c@ bl = tif 1 tliteral /string tloop tthen
   tthen t;
t: range over + swap t;

t: source source-ptr @ ?dup 0= tif input-buffer tthen
  source-len @ t;

t: source@ source drop >in @ + t;
t: next-char source@ c@ 1 tliteral >in +! t;
t: source-rest source@ source + over - t;

t: nextbl t|: 2dup u> tif dup c@ bl = 0= tif 1+ tloop tthen
   tthen nip t;
t: token -leading 2dup range nextbl nip over - t;
t: word source-rest token 2dup + source drop - >in ! t;

\ ===

t: c@+ dup 1+ swap c@ t;

\ todo
t: string~= t;

t: name cell + c@+ t;

( name len start -- addr )
\ todo note, could use a pure string=, could convert names to lowercase on define
t: locate t|: dup tif 3dup name string~= 0= tif @ tloop tthen tthen nip nip t;

\ todo need to check it isn't 0 before dereferencing it
\ another thing could be that '0 @' is 0
t: locskip 3dup locate dup current @ @ = tif drop @ locate telse
   >r 3drop r> tthen t;

t: locprev state @ tif locskip telse locate tthen t;

t: find 2dup context @ @ locprev ?dup tif nip nip telse
  fvocab @ locprev tthen t;

( name len -- compiler-word? addr/0 )
t: lookup
   2dup cvocab @ locprev ?dup tif nip nip true swap telse
   2dup find ?dup tif nip nip false swap telse 2drop 0 tliteral
   tthen tthen t;

\ ===

t: negative? drop c@ '-' tliteral = t;
t: char? 3 tliteral = swap dup c@ ''' tliteral = swap
   2 tliteral + c@ ''' tliteral = and and t;

( str len -- # )
t: >base drop c@
   dup '%' tliteral = tif drop  2 tliteral telse
   dup '#' tliteral = tif drop 10 tliteral telse
       '$' tliteral = tif      16 tliteral telse
       base @
   tthen tthen tthen t;
t: >char drop 1+ c@ t;

t: pad here 64 tliteral + t;

( digit base -- )
t: accumulate pad @ * + pad ! t;

t: in[,] rot tuck >= -rot <= and t;

t: char>digit
    dup '0' tliteral '9' tliteral in[,] tif '0' tliteral - telse
    dup 'A' tliteral 'Z' tliteral in[,] tif '7' tliteral - telse
    dup 'a' tliteral 'z' tliteral in[,] tif 'W' tliteral - telse
  tthen tthen tthen t;

( str len base -- number t/f )
t: >number,base
   >r range 0 tliteral pad !
   t|: 2dup u> tif dup c@ char>digit dup r@ < tif r@ accumulate 1+ tloop tthen tthen
   r> drop = tif pad @ true telse drop false tthen t;

\ ( str len -- number t/f )
t: >number 2dup char? tif >char true exit tthen 2dup negative? -rot
   third tif 1 tliteral /string tthen 2dup >base >number,base
   tif swap tif negate tthen true telse drop false tthen t;

\ ===

t: execute execreg tliteral ! jump execreg t, t;

t: >cfa name + aligned t;
t: lit, lit lit , t;

t: onlookup 0= state @ and tif >cfa , telse >cfa execute tthen t;
t: onnumber state @ tif lit, , tthen t;

t: resolve
    2dup lookup ?dup tif 2swap 2drop swap onlookup telse
    2dup >number     tif -rot 2drop       onnumber telse
    \ todo
    \ on word not found
  tthen tthen t;

t: refill,user input-buffer 128 tliteral accept source-len ! 0 tliteral >in ! t;
t: refill source-ptr @ tif false telse refill,user true tthen t;

t: word! word ?dup 0= tif drop refill tif tloop telse 0 tliteral tthen tthen t;

t: interpret word! ?dup tif resolve tloop telse drop tthen t;

'taddr interpret execreg t!

\ ===

0 there .mem
." after compile: " .s cr
." mem size: " there . cr

forth definitions
