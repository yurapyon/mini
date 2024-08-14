word ] define ' enter @ , ' lit , 1 , ' state , ' ! , ' exit ,
1 context !
word [ define ' enter @ , ' lit , 0 , ' state , ' ! , ' exit ,
word ['] define ' enter @ , ' ' , ' lit , ' lit , ' , , ' , , ' exit ,
0 context !

word forth    define ] bye 0 context ! [ ' exit ,
word compiler define ] 1 context ! [ ' exit ,

word : define ] word define ] [ ' exit ,
compiler
word ; define ] ['] exit , [ ' [ , ' exit ,
forth

bye

: \ source >in ! drop ;

: <> = 0= ;

: 2dup  over over ;
: 2drop drop drop ;
: 3drop drop 2drop ;

\ vs. ',' and '!', 'cell,' and 'cell!' don't care about alignment
: c!+   tuck c! 1+ ;
: cell, cell>bytes c, c, ;
: cell! swap cell>bytes rot c!+ c! ;

: cell 2 ;
: cells cell * ;

: u/   u/mod nip ;
: umod u/mod drop ;
: /    /mod nip ;
: mod  /mod drop ;

: allot   here +! ;
: aligned dup cell mod + ;
: align   here @ aligned here ! ;

: name-len 2 + c@ ;
: >cfa dup name-len + 3 + aligned ;
: last latest @ >cfa ;

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
compiler
: recurse  last xt-jump, ;
forth

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
compiler
: [compile] ' xt-call, ;

: if   ?br, (later)c, ;
: else br,  (later)c, swap distc! ;
: then distc! ;

: cond    0 ;
: endcond ?dup if [compile] then recurse then ;

: case    [compile] cond    ['] >r c, ;
: endcase [compile] endcond ['] r> c, ['] drop c, ;
: of      ['] r@ c, ['] = c, [compile] if ;
: endof   [compile] else ;
forth

: char word drop c@ ;
compiler
: [char] litc, char c, ;
forth

: +-() case
    [char] ( of 1+ endof
    [char] ) of 1- endof
  endcase ;

:noname next-char +-() dup if recurse then ;
: ( 1 [ xt-call, ] drop ;

compiler
:noname [compile] ( ;
: ( [ xt-jump, ] ; \ this comment is to fix vim syntax highlight )

:noname [compile] \ ;
: \ [ xt-jump, ] ;
forth

\ ===

: binary 2 base ! ;
: decimal 10 base ! ;
: hex 16 base ! ;

: min 2dup > if swap then drop ;
: max 2dup < if swap then drop ;

\ ( value min max -- value )
: clamp rot min max ;
: within[] 2 pick >r clamp r> = ;
: within[) 1- within[] ;

: numeric?   [char] 0 [char] 9 within[] ;
: capital?   [char] A [char] Z within[] ;
: lowercase? [char] a [char] z within[] ;

: char>digit cond
    dup numeric?   if [char] 0 -      else
    dup capital?   if [char] A - 10 + else
    dup lowercase? if [char] a - 10 + else
  endcond ;

\ ===

: >body  6 + ;
: >does  >body 3 - ;
: does!  last >does ['] jump swap c!+ cell! ;
: create word define something, return, this! ;
compiler
: does>  something, ['] does! xt-call, exit, this! ;
forth

: constant create , does> @ ;
: enum     dup constant 1+ ;
: flag     dup constant 1 lshift ;

: offsetter create , does> @ + ;
: +field    over offsetter + ;
: field     swap aligned swap +field ;

: variable create cell allot ;

\ ===

compiler
: assign lit, here @ 5 + cell, ['] swap c, ['] ! c, exit, ;
forth

\ push address, push length, jump over the data
: header, something, something, somewhere, rot this! ;

: next-digit next-char char>digit ;

: read-byte next-digit 16 * next-digit + ;

variable readc

: ascii readc assign ;

: escaped readc assign
  dup [char] \ = if
    drop next-char
    dup case
      [char] n of drop 10 endof
      [char] x of drop read-byte endof
    endcase
  then ;

ascii

: read-str, next-char dup [char] " <> if readc @ execute c, recurse then ;
: string, next-char drop read-str, drop ;

compiler
: "  header, swap here @ string, dist swap cell! this! ;
: s" ascii   [compile] " ; \ this comment is to fix vim syntax highlight "
: e" escaped [compile] " ; \ this comment is to fix vim syntax highlight "
forth

\ ===

: dyn, define next, ;
: dyn! >cfa 1+ this! ;
: :dyn word find if drop dyn! else dyn, then ] ;

\ ===

: hello e" hellow\x0aasdf" ;

hello ##type ##cr

##.d

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
