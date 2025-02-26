here constant bootstrap-start

compiler definitions
: do.dup [compile] |: ['] dup , [compile] if ;
forth definitions

: source@ source drop >in @ + ;
: next-char source@ c@ 1 >in +! ;

: source-rest source@ source + over - ;

: nextbl do.u> dup c@ bl <> if 1+ godo then nip ;
: token -leading 2dup range nextbl nip over - ;
: word source-rest token 2dup + source drop - >in ! ;

( name len start -- addr )
: locate do.dup 3dup name string~= 0= if @ godo then nip nip ;

\ todo need to check it isn't 0
: locskip 3dup locate dup current @ @ = if drop @ locate else
  >r 3drop r> then ;

: locprev state @ if locskip else locate then ;

: find 2dup context @ @ locprev ?dup if nip nip else
  forth-latest @ locprev then ;

( name len -- compiler-word? addr/0 )
: lookup cond
  2dup compiler-latest @ locprev ?dup if nip nip true  swap else
  2dup find                      ?dup if nip nip false swap else
  2drop 0 endcond ;

\ note doesnt work well with strings created in interpreter
\ would have to copy the string first then set the length
: str, dup c, tuck here swap move allot ;

: define align here >r
  current @ @ , str, align
  r> dup current @ ! ;

: ' word find ?dup if >cfa then ;

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
    type ." ?" cr
  endcond ;

: _interpret word! ?dup if resolve loop else drop then ;

bootstrap-start dist ./k cr

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
