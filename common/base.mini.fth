word ##.s      define ' ext c, 0 c, 0 c, ' exit c,
word flipb!    define ] tuck c@ xor swap c! [ ' exit c,
word flipt!    define ] 0x80 swap rshift swap >terminator flipb! [ ' exit c,
word immediate define ] latest @ 1 flipt! [ ' exit c,
word hide      define ]          2 flipt! [ ' exit c,
word :         define ] word define latest @ hide ] [ ' exit c,
word ;         define ] ['] exit c, latest @ hide [ ' [ c, ' exit c, immediate

: exit, ['] exit c, ;
: br,   ['] branch  c, ;
: ?br,  ['] branch0 c, ;
: jump, ['] jump c, ;
: call, ['] call c, ;
: lit,  ['] lit  c, ;
: litc, ['] litc c, ;
: ext,  ['] ext c, ;

: blank,     0 c, 0 c, ;
: blankc,    0 c, ;
: (later),   here @ blank, ;
: (later)c,  here @ blankc, ;
: something, lit, (later), ;
: somewhere, jump, (later), ;

: c!+ tuck c! 1+ ;

: cell, cell>bytes c, c, ;
: cell! swap cell>bytes rot c!+ c! ;

: this   here @ swap ;
: dist   this - ;
: this!  this cell! ;
: distc! dup dist swap c! ;
: back,  dist negate c, ;

: xt-call, call, cell, ;
: xt-jump, jump, cell, ;
: return,  exit, blank, ;
: next,    here @ 3 + xt-jump, ;

: if   ?br, (later)c, ; immediate
: else br,  (later)c, swap distc! ; immediate
: then distc! ; immediate

: begin here @ ; immediate
: until ?br, back, ; immediate
: again br,  back, ; immediate
: while ?br, (later)c, ; immediate
: repeat swap br, back, distc! ; immediate

: char   word drop c@ ;
: [char] litc, char c, ; immediate

: \ begin next-char 10 = until ; immediate

: is()
  dup [char] ( = if  drop 1 [ exit, ] then
      [char] ) = if      -1 [ exit, ] then
  0 ;

: ( 1 begin next-char is() + dup 0= until drop ; immediate

: 2dup over over ;
: 2drop drop drop ;
: 2over 3 pick 3 pick ;
: 3dup 2 pick 2 pick 2 pick ;
: 3drop drop 2drop ;

: cell 2 ;
: cells cell * ;

: binary 2 base ! ;
: decimal 10 base ! ;
: hex 16 base ! ;

: u/   u/mod nip ;
: umod u/mod drop ;
: /    /mod nip ;
: mod  /mod drop ;

: min 2dup > if swap then drop ;
: max 2dup < if swap then drop ;

\ ( value min max -- value )
: clamp rot min max ;
: within[] 2 pick >r clamp r> = ;
: within[) 1- within[] ;

: aligned dup cell mod + ;
: align   here @ aligned here ! ;

: :noname 0 0 define here @ ] ;
: >cfa    >terminator 1+ ;
: last    latest @ >cfa ;
: recurse last xt-jump, ; immediate

\ ===

: >body  6 + ;
: >does  >body 3 - ;
: does!  last >does ['] jump swap c!+ cell! ;
: create word define something, return, this! ;
: does>  something, ['] does! xt-call, exit, this! ; immediate

: allot here +! ;
: constant create , does> @ ;
: enum     dup constant 1+ ;
: flag     dup constant 1 lshift ;
: variable create cell allot ;

: idxer  create , does> @ + ;
: +field over idxer + ;
: field  swap aligned swap +field ;

\ ===

: str-end? [char] " = ;

: string,
  next-char drop
  begin
    next-char dup str-end? 0=
  while
    c,
  repeat
  drop ;

\ you can define different string routines
\ then set them to a callback
\ then string, calls them
\ TODO look into ASSIGN from polyforth
: header, something, something, somewhere, rot this! ;
: s"      header, swap here @ string, dist swap ! this! ; immediate

: ext, ['] ext c, cell, ;
: ##.s    [ 0x0000 ext, ] ;
: ##break [ 0x0001 ext, ] ;
: ##type  [ 0x0002 ext, ] ;
: ##cr    [ 0x0003 ext, ] ;
: ##.d    [ 0x0004 ext, ] ;

##.d

: dyn, define next, ;
: dyn! >cfa 1+ this! ;
: :dyn
  word find if drop dyn! else dyn, then
  latest @ hide ] ;

:dyn can-redefine 1 2 3 ##.s drop drop drop ;
: thisthing can-redefine ;

thisthing

:dyn can-redefine 4 5 6 ##.s drop drop drop ;

thisthing

' thisthing execute

##.s


bye



: asdf s" this is  a string" ;

asdf ##type ##cr


word hello ##type ##cr
##mem

\ : banner s" : mini ;" ##type ##cr ;

\ banner

bye

\ should this file have to end with 'bye' or 'quit' ?

\ including files needs an interpreter
\ unless...
\ including files can be done with devices

bye

