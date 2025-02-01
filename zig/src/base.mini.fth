word enter# define ' enter @ , ' lit , ' enter @ , ' exit ,

word ] define enter# , ' lit , 1 , ' state , ' ! , ' exit ,
1 context !
word [ define enter# , ' lit , 0 , ' state , ' ! , ' exit ,
0 context !

word : define enter# , ] word define enter# , ] [ ' exit ,
1 context !
: ; lit exit , [ ' [ , ' exit ,
0 context !

: forth    0 context ! ;
: compiler 1 context ! ;

: source source-ptr @ source-len @ ;
: \ source-len @ >in ! ;

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
: name >name-len c@+ ;
: >cfa >name-len dup c@ + 1 + aligned ;
: last latest @ >cfa ;

: :noname 0 0 define here @ enter# , ] ;

: lit, lit lit , ;
compiler
: ['] lit, ' , ;
forth

: (later), here @ 0 , ;

: this  here @ swap ;
: this! this ! ;
: dist  this - ;

: (data), lit, (later), ['] jump , (later), swap this! ;

compiler
: [compile] ' , ;

: if   ['] jump0 , (later), ;
: else ['] jump , (later), swap this! ;
: then this! ;

: recurse ['] jump , last cell + , ;

: cond    0 ;
: endcond ?dup if [compile] then recurse then ;
forth

: char word drop c@ ;
compiler
: [char] lit, char , ;
forth

\ ===

: binary 2 base ! ;
: decimal 10 base ! ;
: hex 16 base ! ;

: min 2dup > if swap then drop ;
: max 2dup < if swap then drop ;

\ todo cleanup
\ ( value min max -- value )
\ : clamp rot min max ;
\ : within[] rot tuck >= -rot <= and ;
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
: create word define enter# , lit, (later), ['] exit , 0 , this! ;
compiler
: does>  lit, (later), ['] does! , ['] exit , this! ;
forth

: variable create cell allot ;

variable goto*
compiler
: `     here @ goto* ! ;
: goto` ['] jump , goto* @ , ;
forth

: constant create , does> @ ;
: enum     dup constant 1+ ;
: flag     dup constant 1 lshift ;

: value create , does> @ ;
\ TODO better error
: vname word find 0= if panic then >cfa >body ;
: to  vname ! ;
: +to vname +! ;
compiler
: to  lit, vname , ['] ! , ;
: +to lit, vname , ['] +! , ;
forth

: +field over create , + does> @ + ;
: field  swap aligned swap +field ;

\ ===

: ( next-char [char] ) = 0= if recurse then ;
' \ ' (
compiler
: ( [ , ] ;
: \ [ , ] ;
forth

\ ===

: read-digit next-char char>digit ;
: read-byte read-digit 16 * read-digit + ;
: read-esc next-char cond
    dup [char] 0 = if drop 0 else
    dup [char] n = if drop 10 else
    dup [char] x = if drop read-byte else
    \ NOTE
    \ \\ and \" are handled by the 'cond' falling through
  endcond ;

: "", next-char drop `
  next-char cond
    dup [char] " = if drop exit else
    dup [char] \ = if drop read-esc else
  endcond c,
  goto` then drop ;

: d" here @ dup "", here ! ;
compiler
: d" (data), "", align this! ;
forth
\ ( i spacing addr -- addr[i*spacing] spacing )
: [] flip over * rot + swap ;

: count @+ ;
: string, (later), here @ "", dist swap ! ;
: s" here @ dup string, here ! ;
compiler
: s" (data), string, align this! ;
forth
: string= rot over = if mem= else 3drop false then ;

\ ===

32 allot here @ constant #end
0 value #start
: <# #end to #start ;
: #> drop #start #end #start - ;
: hold -1 +to #start #start c! ;
: # base @ /mod digit>char hold ;
: #s dup 0= if # else ` # dup if goto` then then ;
: #pad dup #end #start - > if over hold recurse then 2drop ;

: h# 16 /mod digit>char hold ;

\ ===

: word! word ?dup 0= if drop refill if recurse then 0 0 then ;

\ TODO
\ this string= needs to be case insensitve
\   string~=
\ this behavior is weird and doesnt panic on EoI
: [if] 0= if ` word! ?dup 0= if panic then s" [then]" count string= 0= if
  goto` then then ;
: [then] ;
: [defined] word find nip ;

\ ===

: wlatest context @ cells wordlists + @ ;

: mem d0 dist ;

: fill 2dup > if rot 2dup swap c! -rot 1+ recurse then 2drop ;

\ ===

variable onwnf
' 2drop onwnf !

: onlookup 0= state @ and if >cfa , else >cfa execute then ;
: onnumber state @ if lit, , then ;

: resolve cond
    2dup lookup  if 2swap 2drop onlookup else 2drop
    2dup >number if -rot  2drop onnumber else drop
    onwnf @ execute
  endcond ;

: interpret word! ?dup if resolve recurse else drop then ;

0 cell field >saved-ptr
  cell field >saved-len
  cell field >saved-at
constant saved-source

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

: evaluate save-source source-len ! source-ptr ! 0 >in !
  interpret restore-source ;

quit

compiler
: assign lit, (later), ['] swap , ['] ! , ['] exit , this! enter# , ;
forth

: next, ['] jump , here @ cell + , ;
: dyn, define enter# , next, ;
: dyn! >cfa 2 cells + this! ;
: :dyn word find if drop dyn! else dyn, then ] ;
