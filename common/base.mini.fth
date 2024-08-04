word flipb!    define ] tuck c@ xor swap c! [ ' exit c,
word flipt!    define ] 0x80 swap rshift swap >terminator flipb! [ ' exit c,
word immediate define ] latest @ 1 flipt! [ ' exit c,
word hide      define ]          2 flipt! [ ' exit c,
word :         define ] word define latest @ hide ] [ ' exit c,
word ;         define ] ['] exit c, latest @ hide [ ' [ c, ' exit c, immediate

: \ source >in ! drop ; immediate

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

: xt-call, call, cell, ;
: xt-jump, jump, cell, ;
: next,    here @ 3 + xt-jump, ;

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
: [compile] ' xt-call, ; immediate

: if   ?br, (later)c, ; immediate
: else br,  (later)c, swap distc! ; immediate
: then distc! ; immediate

: begin here @ ; immediate
: until ?br, back, ; immediate
: again br,  back, ; immediate
: while ?br, (later)c, ; immediate
: repeat swap br, back, distc! ; immediate

: cond    0 ; immediate
: endcond begin ?dup while [compile] then repeat ; immediate

: case    [compile] cond    ['] >r c, ; immediate
: endcase [compile] endcond ['] r> c, ['] drop c, ; immediate
: of      ['] r@ c, ['] = c, [compile] if ; immediate
: endof   [compile] else ; immediate

: char word drop c@ ;
: [char] litc, char c, ; immediate

: +-()
  case
    [char] ( of 1+ endof
    [char] ) of 1- endof
  endcase ;

: ( 1 begin next-char +-() dup 0= until drop ; immediate

\ ===

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

: allot here +! ;
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

: str-end? [char] " = ;

: string,
  next-char drop
  begin next-char dup str-end? 0=
  while c, repeat
  drop ;

\ TODO
\ look into ASSIGN from polyforth
\   you can define different string reading routines
\     then set them to a callback
\     then 'string,' calls them
: s" header, swap here @ string, dist swap ! this! ; immediate

\ ===

: dyn, define next, ;
: dyn! >cfa 1+ this! ;
: :dyn
  word find if drop dyn! else dyn, then
  latest @ hide ] ;

\ ===

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
