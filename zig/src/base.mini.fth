word enter# define ' enter @ , ' lit , ' enter @ , ' exit ,

word ] define enter# , ' lit , 1 , ' state , ' ! , ' exit ,
compiler-latest current !
word [ define enter# , ' lit , 0 , ' state , ' ! , ' exit ,
forth-latest current !

word : define enter# , ] word define enter# , ] [ ' exit ,
compiler-latest current !
: ; lit exit , [ ' [ , ' exit ,
forth-latest current !

: forth       forth-latest context ! ;
: compiler    compiler-latest context ! ;
: definitions context @ current ! ;

: source source-ptr @ source-len @ ;
: \ source nip >in ! ;
\ redefine for compiler
' \
compiler definitions
: \ [ , ] ;
forth definitions

: (later), here @ 0 , ;
: this  here @ swap ;
: this! this ! ;
: dist  this - ;

: lit, lit lit , ;
: (lit), lit, (later), ;
compiler definitions
: ['] lit, ' , ;
: [compile] ' , ;

: if   ['] jump0 , (later), ;
: else ['] jump , (later), swap this! ;
: then this! ;
forth definitions

: cell 2 ;
: cells cell * ;

: @+ dup cell + swap @ ;
: !+ tuck ! cell + ;
: c@+ dup 1+ swap c@ ;
: c!+ tuck c! 1+ ;

: allot   here +! ;
: aligned dup cell mod + ;
: align   here @ aligned here ! ;

: name cell + c@+ ;
: >cfa name + aligned ;
: last current @ @ >cfa ;

: >body  5 cells + ;
: >does  >body 2 cells - ;
: does!  last >does ['] jump swap !+ ! ;
: create word define enter# , (lit), ['] exit , 0 , this! ;
compiler definitions
: does>  (lit), ['] does! , ['] exit , this! ;
forth definitions

: variable create , ;

0 variable loop*
: set-loop here @ loop* ! ;
compiler definitions
: |:    set-loop ;
\ todo rename to '<:' ?
: loop ['] jump , loop* @ , ;
forth definitions
\ redefining :
' : : : [ , ] set-loop ;

compiler definitions
: cond    0 ;
: endcond ?dup if [compile] then loop then ;
forth definitions

: ( next-char ')' = 0= if loop then ;
\ redefine for compiler
' (
compiler definitions
: ( [ , ] ;
forth definitions

\ $ forth something
\ : $ word find drop

\ types ===

: constant create , does> @ ;
: enum     dup constant 1+ ;
: flag     dup constant 1 lshift ;

: value create , does> @ ;
\ TODO better error
: vname word find 0= if panic then >cfa >body ;
: to  vname ! ;
: +to vname +! ;
compiler definitions
: to  lit, vname , ['] ! , ;
: +to lit, vname , ['] +! , ;
forth definitions

: +field over create , + does> @ + ;
: field  swap aligned swap +field ;

\ math ===

: binary 2 base ! ;
: decimal 10 base ! ;
: hex 16 base ! ;

: negate 0 swap - ;

: 2dup  over over ;
: 2drop drop drop ;
: 2swap flip >r flip r> ;
: 3drop drop 2drop ;

: <> = 0= ;
: min 2dup > if swap then drop ;
: max 2dup < if swap then drop ;

-1 enum %lt enum %eq constant %gt
: compare 2dup = if 2drop %eq else > if %gt else %lt then then ;
: 2compare >r swap >r compare r> r> compare ;

\ ( value min max -- value )
: clamp rot min max ;
: in[,] rot tuck >= -rot <= and ;
: in[,) 1- in[,] ;

: char word drop c@ ;

: char>digit cond
    dup '0' '9' in[,] if '0' - else
    dup 'A' 'Z' in[,] if '7' - else
    dup 'a' 'z' in[,] if 'W' - else
  endcond ;

: digit>char dup 10 < if '0' else 10 - 'a' then + ;

\ ( end start split -- end start+split start+split start )
: split over + tuck swap ;
\ ( addr ct -- end-addr start-addr )
: range over + swap ;
\ ( start end addr -- addr ct )
: slice flip tuck - -rot + swap ;
\ ( i spacing addr -- addr[i*spacing] spacing )
: [] flip over * rot + swap ;

\ strings ===

: (data), (lit), ['] jump , (later), swap this! ;

: read-digit next-char char>digit ;
: read-byte read-digit 16 * read-digit + ;
: read-esc next-char cond
    dup '0' = if drop 0 else
    dup 'n' = if drop 10 else
    dup 'x' = if drop read-byte else
    \ NOTE
    \ \\ and \" are handled by the 'cond' falling through
  endcond ;

: "", next-char drop |:
  next-char cond
    dup '"' = if drop exit else
    dup '\' = if drop read-esc else
  endcond c, loop then ;

: d" here @ dup "", here ! ;
compiler definitions
: d" (data), "", align this! ;
forth definitions

: count @+ ;
: string, (later), here @ "", dist swap ! ;
: c" here @ dup string, here ! ;
: s" [compile] c" count ;
compiler definitions
: c" (data), string, align this! ;
: s" [compile] c" ['] count , ;
forth definitions

: string= rot over = if mem= else 3drop false then ;

\ number print ===

: pad here @ 64 + ;

0 value #start
: <# pad to #start ;
: #> drop #start pad #start - ;
: hold -1 +to #start #start c! ;
: # base @ /mod digit>char hold ;
: #s dup 0= if # else |: # dup if loop then then ;
: #pad dup pad #start - > if over hold loop then 2drop ;

\ todo
\   holds
\   sign

: h# 16 /mod digit>char hold ;

\ ===

: get-word word ?dup 0= if drop refill if loop else 0 0 then then ;

\ TODO
\ this string= needs to be case insensitve
\   string~=
\ this behavior is weird and doesnt panic on EoF
: [if] 0= if |: get-word ?dup 0= if panic then
  s" [then]" string= 0= if loop then then ;
: [then] ;
: [defined] word find nip ;

\ ===

: :noname 0 0 define here @ enter# , set-loop ] ;

compiler definitions
: [: lit, here @ 6 + , ['] jump , (later), enter# , ;
: ;] ['] exit , this! ;
forth definitions

\ ===

: mem d0 dist ;

: fill   >r range |: 2dup > if r@ swap c!+ loop then r> 3drop ;
: fill16 >r range |: 2dup > if r@ swap  !+ loop then r> 3drop ;
: erase 0 fill ;

: s[ 0 ;
: ]s constant ;

: swapmem over @ over @ 2swap >r ! r> ! ;

\ evaluation ===

' 2drop variable onwnf

: onlookup 0= state @ and if >cfa , else >cfa execute then ;
: onnumber state @ if lit, , then ;

: resolve cond
    2dup lookup  if 2swap 2drop onlookup else 2drop
    2dup >number if -rot  2drop onnumber else drop
    onwnf @ execute
  endcond ;

: interpret get-word ?dup if resolve loop else drop then ;

s[
  cell field >saved-ptr
  cell field >saved-len
  cell field >saved-at
]s saved-source

\ note
\ saved-max is also used for blkstack
8 constant saved-max
create saved-stack saved-max saved-source * allot
saved-stack value saved-tos

: save-source
  source-ptr @ saved-tos >saved-ptr !
  source-len @ saved-tos >saved-len !
  >in @        saved-tos >saved-at !
  saved-source +to saved-tos ;

: restore-source
  saved-source negate +to saved-tos
  saved-tos >saved-ptr @ source-ptr !
  saved-tos >saved-len @ source-len !
  saved-tos >saved-at @  >in ! ;

: set-source source-len ! source-ptr ! 0 >in ! ;

: evaluate save-source set-source interpret restore-source ;

\ ===

: vocabulary create 0 , does> context ! ;

0 [if]

compiler
: assign (lit), ['] swap , ['] ! , ['] exit , this! enter# , ;
forth

: next, ['] jump , here @ cell + , ;
: dyn, define enter# , next, ;
: dyn! >cfa 2 cells + this! ;
: :dyn word find if drop dyn! else dyn, then ] ;

[then]
