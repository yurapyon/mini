word #imm      define ] 0x40 [ ' exit c,
word flipb!    define ] tuck c@ xor swap c! [ ' exit c,
word immediate define ] #imm latest @ >terminator flipb! [ ' exit c,
word :         define ] word define ] [ ' exit c,
word ;         define ] ['] exit c, [ ' [ c, ' exit c, immediate

: \ source >in ! drop ; immediate

: <> = 0= ;

: 2dup over over ;
: 2drop drop drop ;
: 3drop drop 2drop ;

: >cfa       >terminator 1+ ;
: immediate? >terminator c@ #imm and ;
: last       latest @ >cfa ;

\ vs. ',' and '!', 'cell,' and 'cell!' don't care about alignment
: c!+   tuck c! 1+ ;
: cell, cell>bytes c, c, ;
: cell! swap cell>bytes rot c!+ c! ;

\ tags
: exit, ['] exit c, ;
: br,   ['] branch  c, ;
: ?br,  ['] branch0 c, ;
: jump, ['] jump c, ;
: call, ['] call c, ;
: lit,  ['] lit  c, ;
: litc, ['] litc c, ;
: ext,  ['] ext c, ;

: :noname  0 0 define here @ ] ;
: xt-call, call, cell, ;
: xt-jump, jump, cell, ;
: next,    here @ 3 + xt-jump, ;
: recurse  last xt-jump, ; immediate

: blank,     0 c, 0 c, ;
: blankc,    0 c, ;
: (later),   here @ blank, ;
: (later)c,  here @ blankc, ;
: something, lit, (later), ;
: somewhere, jump, (later), ;
: return,    exit, blank, ;

: this   here @ swap ;
: dist   this - ;
: this!  this cell! ;
: distc! dup dist swap c! ;
: back,  dist negate c, ;

\ basic syntax
: if   ?br, (later)c, ; immediate
: else br,  (later)c, swap distc! ; immediate
: then distc! ; immediate

: compile,  lit, cell, ['] xt-call, xt-call, ;
: postpone, dup immediate? if >cfa xt-call, else >cfa compile, then ;
: postpone  word find 2drop postpone, ; immediate

: cond    0 ; immediate
: endcond ?dup if postpone then recurse then ; immediate

: case    postpone cond    ['] >r c, ; immediate
: endcase postpone endcond ['] r> c, ['] drop c, ; immediate
: of      ['] r@ c, ['] = c, postpone if ; immediate
: endof   postpone else ; immediate

: char word drop c@ ;
: [char] litc, char c, ; immediate

: +-()
  case
    [char] ( of 1+ endof
    [char] ) of 1- endof
  endcase ;

:noname next-char +-() dup if recurse then ;
: ( 1 [ xt-call, ] drop ; immediate

\ ===

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

\ ===

: allot   here +! ;
: aligned dup cell mod + ;
: align   here @ aligned here ! ;

: >body  6 + ;
: >does  >body 3 - ;
: does!  last >does ['] jump swap c!+ cell! ;
: create word define something, return, this! ;
: does>  something, ['] does! xt-call, exit, this! ; immediate

: constant create , does> @ ;
: enum     dup constant 1+ ;
: flag     dup constant 1 lshift ;

: offsetter create , does> @ + ;
: +field    over offsetter + ;
: field     swap aligned swap +field ;

: variable create cell allot ;

\ ===

\ push address, push length, jump over the data
: header, something, something, somewhere, rot this! ;

:noname next-char dup [char] " <> if c, recurse then ;
: string, next-char drop [ xt-call, ] drop ;

\ TODO
\ look into ASSIGN from polyforth
\   you can define different string reading routines
\     then set them to a callback
\     then 'string,' calls them
: s" header, swap here @ string, dist swap ! this! ; immediate

\ ===

: dyn, define next, ;
: dyn! >cfa 1+ this! ;
: :dyn word find if drop dyn! else dyn, then ] ;

\ ===

: hello s" hellow" ;

hello ##type ##cr

\ TODO
\ should this file have to end with 'bye' or 'quit' ?
bye

variable ahere
0 ahere !

: a! ;
: a@ ;

: a, ahere ! 1 ahere +! ;

: label ahere @ constant ;

: `br, ;
: `?br, ;
: `(later), ahere @ 0 a, ;

: `this  ahere @ swap ;
: `dist  `this - ;
: `dist! dup `dist swap a! ;
: `back, `dist negate a, ;

: `if `?br, `(later), ;
: `then `dist! ;

label `?dup
  `dup `0= `if `drop `then

bye
