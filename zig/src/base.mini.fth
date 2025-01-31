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

: /mod 2dup / -rot mod ;

: cell 2 ;
: cells cell * ;

: @+ dup cell + swap @ ;
: !+ tuck ! cell + ;
: c@+ dup 1+ swap c@ ;
: c!+ tuck c! 1+ ;
: split over + tuck swap ;
: range over + swap ;

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

: (later), here @ 0 , ;

: this  here @ swap ;
: this! this ! ;
: dist  this - ;

\ basic syntax
compiler
: [compile] ' , ;

: if   ['] jump0 , (later), ;
: else jump, (later), swap this! ;
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

:noname next-char [char] ) = 0= if recurse then ;
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
\ : clamp rot min max ;
: within[] rot tuck >= -rot <= and ;
\ : within[) 1- within[] ;

: char>digit
  dup [char] 0 >= if [char] 0 - then
  dup 17 >= if  7 - then
  dup 42 >= if 32 - then ;

: digit>char dup 10 < if [char] 0 else 10 - [char] a then + ;

\ ===

: >body  5 cells + ;
: >does  >body 2 cells - ;
: does!  last >does ['] jump swap !+ ! ;
: create word define enter-code , lit, (later), exit, 0 , this! ;
compiler
: does>  lit, (later), ['] does! , exit, this! ;
forth

: variable create cell allot ;

: constant create , does> @ ;
: enum     dup constant 1+ ;
: flag     dup constant 1 lshift ;

: value create , does> @ ;
\ TODO better error
: vname word find 0= if panic then >cfa >body ;
: to  vname ! ;
: +to vname +! ;
compiler
: to  vname lit, , ['] ! , ;
: +to vname lit, , ['] +! , ;
forth

: +field over create , + does> @ + ;
: field  swap aligned swap +field ;

variable mark
compiler
: ` here @ mark ! ;
: loop` jump, mark @ , ;
forth

\ ===

: read-digit next-char char>digit ;
: read-byte read-digit 16 * read-digit + ;

: count @+ ;

: (data), lit, (later), jump, (later), swap this! ;

: "",
  next-char drop `
  next-char dup [char] " <> if
    dup [char] \ = if drop next-char
      dup case
        [char] 0 of drop 0 endof
        [char] n of drop 10 endof
        [char] x of drop read-byte endof
        \ NOTE
        \ \\ and \" are handled by the 'case' falling through
      endcase
    then
    c, loop`
  then drop ;

: string, (later), here @ "", dist swap ! ;

: s" here @ dup string, here ! ;

compiler
: s" (data), string, align this! ;
forth

: string= rot over = if mem= else 3drop false then ;

: d" here @ dup "", here ! ;
compiler
: d" (data), "", align this! ;
forth
: [] ( i spc addr -- ) flip over * rot + swap ;

\ ===

32 allot here @ constant #end
0 value #start
: <# #end to #start ;
: #> drop #start #end #start - ;
: hold -1 +to #start #start c! ;
: # base @ /mod digit>char hold ;
: #s dup 0= if # else ` # dup if loop` then then ;
: #pad dup #end #start - > if over hold recurse then 2drop ;

: h# 16 /mod digit>char hold ;

\ ===

: tilword word ?dup 0= if drop refill if recurse then panic then ;

\ TODO this string= needs to be case insensitve
: [if] 0= if ` tilword s" [then]" count string= 0= if loop` then then ;
: [then] ;
: [defined] word find nip ;

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

: interpret tilword resolve recurse ;

: fill 2dup > if rot 2dup swap c! -rot 1+ recurse then 2drop ;

quit

compiler
: assign lit, (later), ['] swap , ['] ! , exit, this! enter-code , ;
forth

: next, jump, here @ cell + , ;
: dyn, define enter-code , next, ;
: dyn! >cfa 2 cells + this! ;
: :dyn word find if drop dyn! else dyn, then ] ;
