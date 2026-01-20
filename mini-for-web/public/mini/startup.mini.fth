: \ source-len @ >in ! ;

\ NOTE
\ Max line length in this file is 128 chars

\ Interpreter starts with forth as the only wordlist in the context

: context     wordlists #order @ 1- cells + ; \ ( -- a )
: push-order  1 #order +! context ! ;         \ ( n -- )
: also        context @ push-order ;          \ ( -- )
: previous    -1 #order +! ;                  \ ( -- )

: forth       fvocab context ! ;              \ ( -- )
: compiler    cvocab context ! ;              \ ( -- )
: definitions context @ current ! ;           \ ( -- )

: @+  dup cell + swap @ ; \ ( a -- a n )
: c@+ dup 1+ swap c@ ;    \ ( a -- a n )
: !+  tuck ! cell + ;     \ ( n a -- a )
: c!+ tuck c! 1+ ;        \ ( n a -- a )

: <>    = 0= ;             \ ( a b -- t/f )
: 2swap >r flip r> flip ;  \ ( a b c d -- c d a b )
: 3drop drop 2drop ;       \ ( a b c -- )

: space bl emit ; \ ( -- )
: cr    10 emit ; \ ( -- )

\ syntax and defining words ===

also compiler definitions
: literal   lit, , ;              \ ( n -- )
: [compile] ' , ;                 \ ( "name" -- )
: [']       ' [compile] literal ; \ ( "name" -- )
previous definitions

: constant word define ['] docon @ , , ;          \ ( n "name" -- )
: enum     dup constant 1+ ;                      \ ( n "name" -- n )
: flag     dup constant 1 lshift ;                \ ( n "name" -- n )
: create   word define ['] docre @ , ['] exit , ; \ ( "name" -- )
\ todo probably remove variable initialization
: variable create , ;                             \ ( n "name" -- )

0 variable loop*
: set-loop here loop* ! ;         \ ( -- )
also compiler definitions
: |:       set-loop ;             \ ( -- )
: loop     ['] jump , loop* @ , ; \ ( -- )
previous definitions
: :        : set-loop ;           \ ( -- )

: (later), here 0 , ;      \ ( -- a )
: (lit),   lit, (later), ; \ ( -- a )
: this     here swap ;     \ ( a0 -- a1 a0 )
: this!    this ! ;        \ ( a -- )

also compiler definitions
: if   ['] jump0 , (later), ;           \ ( -- a )
: else ['] jump , (later), swap this! ; \ ( a -- a )
: then this! ;                          \ ( a -- )

: u>?|:  [compile] |: ['] 2dup , ['] u> , [compile] if ; \ ( -- a ) deprecated
: dup?|: [compile] |: ['] dup , [compile] if ;           \ ( -- a ) deprecated

: check>  [compile] |: ['] 2dup , ['] u> , ; \ ( -- )
: check!0 [compile] |: ['] dup , ;           \ ( -- )

0 constant cond
: endcond check!0 if [compile] then loop then drop ; \ ( 0 ... a -- )

: tailcall ['] jump , ' cell + , ; \ ( "name" -- )
previous definitions

: ( next-char ')' = 0= if loop then ;
also compiler definitions
: ( ( ; \ this comment is here to fix vim syntax highlight )
: \ \ ;
previous definitions

: :noname ( -- a ) 0 0 define here ['] docol @ , set-loop ] ;
also compiler definitions
: [:      ( -- a ) lit, here 6 + , ['] jump , (later), ['] docol @ , ;
: ;]      ( a -- ) ['] exit , this! ;
previous definitions

: last  ( -- a )   current @ @ >cfa ;
: >does ( a -- a ) cell + ;
also compiler definitions
: does> ( -- )     (lit), ['] last , ['] >does , ['] ! , ['] exit , this!
                   ['] docol @ , set-loop ;
previous definitions
: does> ( -- )     last :noname swap >does ! ;

: >value 2 cells + ;

: noop ( -- )        ;
: doer ( "name" -- ) create ['] noop cell + , does> @ >r ;
0 variable make*
also compiler definitions
: make ( "name" -- ) (lit), lit, ' >value , ['] ! ,
                     here make* ! ['] exit , 0 , this! ;
: ;and ( -- )        ['] exit , ['] jump make* @ !+ this! ;
previous definitions
: make ( "name" -- ) :noname cell + ' >value ! ;
: undo ( "name" -- ) ['] noop cell + ' >value ! ;

: value ( n "name" -- ) create , does> @ ;
: to    ( n "name" -- ) ' >value ! ;
: +to   ( n "name" -- ) ' >value +! ;
also compiler definitions
: to    ( "name" -- )   lit, ' >value , ['] ! , ;
: +to   ( "name" -- )   lit, ' >value , ['] +! , ;
previous definitions

: defer ( "name" -- )  create ['] noop , ['] exit , does> >r ;
: is    ( a "name" --) ' >value ! ;

0 constant s[
: ]s     ( n "name" -- )     constant ;
: +field ( a n "name" -- a ) over create , + does> @ + ;
: field  ( a n "name" -- a ) swap aligned swap +field ;

: type   ( a n -- ) range check> if c@+ emit loop then 2drop ;
: spaces ( n -- )   0 check> if space 1+ loop then 2drop ;

:noname type '?' emit cr abort ; wnf !
\ todo
\ :noname source-ptr @ 0= if source type cr >in @ spaces '*' emit cr then ;
\ on-quit !

: external word 2dup extid -rot define , ;

\ search order ===

: set-order 0 #order ! >r |: r@ if
    push-order r> 1- >r
  loop then r> drop ;

: vocabulary ( "name" -- ) create 0 , does> context ! ;
: >vocab     2 cells + ;

vocabulary root

also root definitions
: forth forth ;
previous definitions

: only ['] root >vocab dup 2 set-order ;

only forth definitions

\ math ===

: binary  ( -- ) 2 base ! ;
: hex     ( -- ) 16 base ! ;
: decimal ( -- ) 10 base ! ;

: min ( n0 n1 -- n ) 2dup > if swap then drop ;
: max ( n0 n1 -- n ) 2dup < if swap then drop ;

: clamp ( n min max -- n ) rot min max ;
: in[,] ( n min max -- n ) rot tuck >= -rot <= and ;
: in[,) ( n min max -- n ) 1- in[,] ;

: /string ( a n0 n1 -- a+n1 n0-n1 ) tuck - -rot + swap ;

\ string parsing ===

: next-digit ( | . -- n )  next-char char>digit ;
: next-byte  ( | .. -- n ) next-digit 16 * next-digit + ;
: escape,    ( | .? -- )
  next-char cond
    dup '0' = if drop 0 c,              else
    dup 't' = if drop 9 c,              else
    dup 'n' = if drop 10 c,             else
    dup 'N' = if drop 10 c, refill drop else
    dup 'x' = if drop next-byte c,      else
    dup '&' = if drop refill drop       else
      c,
  endcond ;

: string ( | .*" -- )
  next-char drop |: next-char cond
    dup '"' = if drop exit    else
    dup '\' = if drop escape, else
      c,
  endcond loop ;

: cstring ( | .*" -- ) (later), here string this - swap ! ;

: count   ( a -- a n ) @+ ;
: (data), ( -- a )     (lit), ['] jump , (later), swap this! ;

: d" ( | .*" -- ) here dup string h ! ;
: c" ( | .*" -- ) here dup cstring h ! ;
: s" ( | .*" -- ) [compile] c" count ;
also compiler definitions
: d" ( | .*" -- ) (data), string align this! ;
: c" ( | .*" -- ) (data), cstring align this! ;
: s" ( | .*" -- ) [compile] c" ['] count , ;
previous definitions

: ." ( | .*" -- ) [compile] s" type ;
also compiler definitions
: ." ( | .*" -- ) [compile] s" ['] type , ;
previous definitions

\ printing ===

: digit>char ( n -- n ) dup 10 < if '0' else 'W' then + ;

: abs   dup 0 < if negate then ;
\ todo umod should come first, then u/, according to gforth and ansi
: u/mod 2dup u/ -rot umod ;

0 variable #start
: #len ( -- n )     pad #start @ - ;
: <#   ( -- )       pad #start ! ;
: #>   ( n -- a n ) drop #start @ #len ;
: hold ( n -- )     -1 #start +! #start @ c! ;
: #    ( n -- n )   base @ u/mod digit>char hold ;
: #s   ( n -- n )   dup 0= if # else |: # dup if loop then then ;
: #pad ( c n -- )   dup #len > if over hold loop then 2drop ;
: h#   ( n -- n )   16 u/mod digit>char hold ;
: sign ( n -- )     0 < if '-' hold then ;

: u.pad ( n n c -- ) rot <# #s flip #pad #> type ;
: u.r   ( n n -- )   bl u.pad ;
: u.0   ( n n -- )   '0' u.pad ;
: u.    ( n -- )     <# #s #> type ;
: .     ( n -- )     <# dup abs #s swap sign #> type space ;

: printable ( n -- t/f) 32 126 in[,] ;
: print     ( n -- )    dup printable 0= if drop '.' then emit ;
: .byte     ( n -- )    <# h# h# #> type ;
: .short    ( n -- )    <# h# h# h# h# #> type ;

: .cells    ( a a -- ) swap cell - check> 0= if dup @ . cell - loop then 2drop ;

: sdata ( -- a n ) s* @ s0 over - ;
: depth ( -- n )   sdata nip cell / ;
: .s    ( -- )     depth ." <" u. ." > " sdata range .cells ;

: rdata  ( -- a n ) r* @ r0 over - cell /string ;
: rdepth ( -- n )   rdata nip cell / 1- ;
: .r     ( -- )     rdepth ." (" u. ." ) " rdata range .cells ;

\ applications ===

\ todo rename []
: []      ( n n a -- a n ) flip over * rot + swap ;
: ctlcode ( n -- a n )
  cond
    dup 32 u< if
      3 d" nulsohstxetxeotenqackbelbs ht lf vt ff cr so si dledc1dc2dc3dc4naksynetbcanem subescfs gs rs us " []
    else
    127 =     if s" del" else
    0 0
  endcond ;
: .ascii ( n -- ) dup printable if emit else ctlcode type then ;
: .col   ( n -- ) dup 3 u.r space dup .byte space .ascii 2 spaces ;
: .row   ( n -- ) 128 range check> if dup .col 32 + loop then 2drop ;
: ashy   ( -- )   32 0 check> if dup .row cr 1+ loop then 2drop ;

: split  ( a n -- a+n a+n a ) over + tuck swap ;
: .bytes ( a a -- ) check> if c@+ .byte space loop then 2drop ;
: .print ( a a -- ) check> if c@+ print loop then 2drop ;
: dump   ( a n -- ) range check> if 16 split dup .short space 2dup .bytes .print cr loop then 2drop ;

: .word ( a -- ) name tuck type if space then ;
: words ( -- )   context @ @ check!0 if dup .word @ loop then drop ;

\ ===

: [if]      0= if |: word! ?dup 0= if panic then s" [then]" string= 0= if loop then then ;
: [then]    ;
: [defined] word find 0= 0= ;

also compiler definitions
: [if]      [if] ;
: [then]    [then] ;
: [defined] [defined] ;
previous definitions

