word enter-code define ' enter @ , ' lit , ' enter @ , ' exit ,

word ] define enter-code , ' lit , 1 , ' state , ' ! , ' exit ,
1 context !
word [ define enter-code , ' lit , 0 , ' state , ' ! , ' exit ,
0 context !

word \ define enter-code , ] source >in ! drop [ ' exit ,

\ equivalent to
\ : : word define enter-code , ] ;
word : define enter-code , ] word define enter-code , ] [ ' exit ,

\ equivalent to
\ : lit, ['] lit , ;
: lit, lit [ ' lit , ] , [ ' exit ,

1 context !

\ equivalent to
\ : ['] ' lit, , ;
: ['] ' lit, , [ ' exit ,

\ equivalent to
\ : ; exit, [compile] [ ;
: ; ['] exit , [ ' [ , ' exit ,

0 context !

: forth    0 context ! ;
: compiler 1 context ! ;

: <> = 0= ;

: 2dup  over over ;
: 2drop drop drop ;
: 3drop drop 2drop ;

: cell 2 ;
: cells cell * ;

: allot   here +! ;
: aligned dup cell mod + ;
: align   here @ aligned here ! ;

: >name-len cell + ;
: >cfa >name-len dup c@ + 1 + aligned ;
: last latest @ >cfa ;

\ tags
: exit,  ['] exit , ;
: jump0, ['] jump0 , ;
: jump,  ['] jump , ;

: :noname 0 0 define here @ enter-code , ] ;
: next,   here @ 2 cells + jump, , ;
compiler
: recurse jump, last cell + , ;
forth

: blank,     0 , ;
: (later),   here @ blank, ;
: something, lit, (later), ;
: somewhere, jump, (later), ;

: this  here @ swap ;
: dist  this - ;
: this! this ! ;

\ basic syntax
compiler
: [compile] ' , ;

: if   jump0, (later), ;
: else jump,  (later), swap this! ;
: then this! ;

: cond    0 ;
: endcond ?dup if [compile] then recurse then ;

: case    [compile] cond    ['] >r , ;
: endcase [compile] endcond ['] r> , ['] drop , ;
: of      ['] r@ , ['] = , [compile] if ;
: endof   [compile] else ;
forth

: char word drop c@ ;
compiler
: [char] lit, char , ;
forth

: +-() case
    [char] ( of 1+ endof
    [char] ) of 1- endof
  endcase ;

:noname next-char +-() dup if recurse then ;
: ( 1 [ , ] drop ;

compiler
\ redefine comment words to work in compile state

:noname [compile] ( ;
: ( [ , ] ; \ this comment is to fix vim syntax highlight )

:noname [compile] \ ;
: \ [ , ] ;
forth

\ ===

: binary 2 base ! ;
: decimal 10 base ! ;
: hex 16 base ! ;

: min 2dup > if swap then drop ;
: max 2dup < if swap then drop ;

\ ( value min max -- value )
: clamp rot min max ;
: within[] rot tuck <= -rot >= and ;
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

: !+ tuck ! cell + ;

: >body  5 cells + ;
: >does  >body 2 cells - ;
: does!  last >does ['] jump swap !+ ! ;
: create word define enter-code , something, exit, blank, this! ;
compiler
: does>  something, ['] does! , exit, this! ;
forth

: variable create cell allot ;

: constant create , does> @ ;
: enum     dup constant 1+ ;
: flag     dup constant 1 lshift ;

: offsetter create , does> @ + ;
: +field    over offsetter + ;
: field     swap aligned swap +field ;

\ ===

\         push address, push length, jump over the data
: header, something, something, somewhere, rot this! ;

compiler
: assign something, ['] swap , ['] ! , exit, this! enter-code , ;
forth

: read-digit next-char char>digit ;
: read-byte read-digit 16 * read-digit + ;

variable read-char

: ascii read-char assign ;

: escaped read-char assign
  dup [char] \ = if
    drop next-char
    dup case
      [char] n of drop 10 endof
      [char] x of drop read-byte endof
    endcase
  then ;

ascii

: read-str, next-char dup [char] " <> if read-char @ execute c, recurse then ;
: string, next-char drop read-str, drop ;

compiler
: "  header, swap here @ string, dist swap ! align this! ;
: s" ascii   [compile] " ; \ this comment is to fix vim syntax highlight "
: e" escaped [compile] " ; \ this comment is to fix vim syntax highlight "
forth

\ ===

bye

: dyn, define enter-code , next, ;
: dyn! >cfa 2 cells + this! ;
: :dyn word find if drop dyn! else dyn, then ] ;

bye

\ ===

: hello e" hellow\x0aasdf" ;

hello ##type ##cr

##.d

\ TODO
\ should this file have to end with 'bye' or 'quit' ?
bye
