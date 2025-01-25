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
: 2swap flip >r flip r> ;
: 3drop drop 2drop ;
: save  over -rot ;

: /mod 2dup / -rot mod ;

: cell 2 ;
: cells cell * ;

: @+ dup cell + swap @ ;
: !+ tuck ! cell + ;
: c@+ dup 1+ swap c@ ;
: c!+ tuck c! 1+ ;

: allot   here +! ;
: aligned dup cell mod + ;
: align   here @ aligned here ! ;

: >name-len cell + ;
: >cfa >name-len dup c@ + 1 + aligned ;
: last latest @ >cfa ;

: name >name-len c@+ ;

\ tags
: exit, ['] exit , ;
: jump, ['] jump , ;

: :noname 0 0 define here @ enter-code , ] ;
compiler
: recurse jump, last cell + , ;
: return exit, ;
forth

: blank,   0 , ;
: (later), here @ blank, ;
: (lit),   lit, (later), ;
: (jump),  jump, (later), ;

: this  here @ swap ;
: this! this ! ;
: dist  this - ;

\ basic syntax
compiler
: [compile] ' , ;

: if   ['] jump0 , (later), ;
: else (jump), swap this! ;
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

:noname next-char case
    [char] ( of 1+ endof
    [char] ) of 1- endof
  endcase ?dup if recurse then ;
: ( 1 [ , ] ;

compiler
' ( : ( [ , ] ; \ this comment is to fix vim syntax highlight )
' \ : \ [ , ] ;
forth

\ ===

: binary 2 base ! ;
: decimal 10 base ! ;
: hex 16 base ! ;

: min 2dup > if swap then drop ;
: max 2dup < if swap then drop ;

\ ( value min max -- value )
: clamp rot min max ;
: within[] rot tuck >= -rot <= and ;
: within[) 1- within[] ;

: char>digit cond
    dup [char] 0 [char] 9 within[] if [char] 0 -      else
    dup [char] A [char] Z within[] if [char] A - 10 + else
    dup [char] a [char] z within[] if [char] a - 10 + else
  endcond ;

: digit>char dup 10 < if [char] 0 else 10 - [char] a then + ;

\ ===

: >body  5 cells + ;
: >does  >body 2 cells - ;
: does!  last >does ['] jump swap !+ ! ;
: create word define enter-code , (lit), exit, blank, this! ;
compiler
: does>  (lit), ['] does! , exit, this! ;
forth

: variable create cell allot ;

: constant create , does> @ ;
: enum     dup constant 1+ ;
: flag     dup constant 1 lshift ;

: value create , does> @ ;
: vname word find drop >cfa >body ;
: to  vname ! ;
: +to vname +! ;
compiler
: to  vname lit, , ['] ! , ;
: +to vname lit, , ['] +! , ;
forth

: offsetter create , does> @ + ;
: +field    over offsetter + ;
: field     swap aligned swap +field ;

\ ===

compiler
: assign (lit), ['] swap , ['] ! , exit, this! enter-code , ;
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
      \ NOTE
      \ \\ and \" are handled by the 'case' falling through
    endcase
  then ;

ascii

: count @+ ;

: (data), (lit), (jump), swap this! ;

: "",
  next-char dup [char] " <> if
    read-char @ execute c, recurse
  then drop ;

: string, (later), here @ "", dist swap ! ;

compiler
: "  next-char drop (data), string, align this! ;
: s" ascii   [compile] " ; \ this comment is to fix vim syntax highlight "
: e" escaped [compile] " ; \ this comment is to fix vim syntax highlight "
forth

: "  next-char drop here @ dup string, here ! ;
: s" ascii   [compile] " ; \ this comment is to fix vim syntax highlight "
: e" escaped [compile] " ; \ this comment is to fix vim syntax highlight "

\ ===

: wlatest context @ cells wordlists + @ ;

: mem d0 dist ;

\ ===

\ todo note
\ if interpret/import is defined,
\ quit has to be redefined in forth ?
\ it seems to work
\ bye is broken though

variable onwnf
' 2drop onwnf !

: onlookup 0= state @ and if >cfa , else >cfa execute then ;
: onnumber state @ if lit, , then ;

: resolve
  cond
  2dup lookup  if 2swap 2drop onlookup else 2drop
  2dup >number if -rot  2drop onnumber else drop
  onwnf @ execute
  endcond ;

: interpret
  word ?dup if resolve recurse
  else drop refill if recurse then
  then ;

quit

\ ===

: next, (jump), this! ;
: dyn, define enter-code , next, ;
: dyn! >cfa 2 cells + this! ;
: :dyn word find if drop dyn! else dyn, then ] ;
