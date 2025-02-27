here constant bootstrap0

vocabulary tcmp
tcmp definitions

8 1024 * allocate constant mem

s[
cell field >_pc
cell field >_cta
cell field >_dsp
cell field >_rsp
cell field >h
cell field >fvocab
cell field >cvocab
cell field >current
cell field >context
]s fk0

: @ mem dyn@ ;
: ! mem dyn! ;
: +! mem dyn+! ;
: c@ mem dync@ ;
: c! mem dync! ;
: c+! mem dync+! ;
: host>target mem >dyn ;

: .print do.u> dup c@ print 1+ godo 2drop ;
: .bytes do.u> dup c@ .byte space 1+ godo 2drop ;
: .mem range do.u> 16 split dup .short space 2dup .bytes .print
  cr godo 2drop ;

fk0 0 >h !
0 0 >fvocab !
0 0 >cvocab !
0 >fvocab 0 >current !

: here 0 >h @ ;
: allot 0 >h +! ;
: , here ! cell allot ;
: c, here c! 1 allot ;
: aligned dup cell mod + ;
: align here aligned 0 >h ! ;

: str, dup c, tuck here swap host>target allot ;
: define align here >r 0 >current @ @ , str, align r> 0 >current @ ! ;

: exit  0 , ;
: docol 1 , ;

: t; exit ;

forth
: deft define ['] docre @ , ['] exit , , does> @ [ tcmp ] , ;

: buit word deft ;

forth
: t: word 2dup
  [ tcmp ] here [ forth ] -rot [ tcmp ] deft
  define docol ;

2 buit @
3 buit !

: .mem .mem ;

forth definitions

0 [if]

\ ===

: b: dup word define , 1+ ;
: b: dup word 2drop drop ;
: bs[ 0 ;
: ]bs ." bytecode ct:" . ;

bs[
b: exit
b: panic
b: abort"
b: quit
b: accept
b: docol
b: docon
b: docre
b: jump
b: jump0
b: lit
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
]bs

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
