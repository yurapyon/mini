: \ source-len @ >in ! ;

\ NOTE
\ Max line length in this file is 128 chars

: forth       fvocab context ! ;    \ ( -- )
: compiler    cvocab context ! ;    \ ( -- )
: definitions context @ current ! ; \ ( -- )

\ utils ===

: cells cell * ; \ ( n -- n )

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

compiler definitions
: literal   lit, , ;              \ ( n -- )
: [compile] ' , ;                 \ ( "name" -- )
: [']       ' [compile] literal ; \ ( "name" -- )
forth definitions

: constant word define ['] docon @ , , ;          \ ( n "name" -- )
: enum     dup constant 1+ ;                      \ ( n "name" -- n )
: flag     dup constant 1 lshift ;                \ ( n "name" -- n )
: create   word define ['] docre @ , ['] exit , ; \ ( "name" -- )
: variable create , ;                             \ ( n "name" -- )

0 variable loop*
: set-loop here loop* ! ;         \ ( -- )
compiler definitions
: |:       set-loop ;             \ ( -- )
: loop     ['] jump , loop* @ , ; \ ( -- )
forth definitions
: :        : set-loop ;           \ ( -- )

: (later), here 0 , ;      \ ( -- a )
: (lit),   lit, (later), ; \ ( -- a )
: this     here swap ;     \ ( a0 -- a1 a0 )
: this!    this ! ;        \ ( a -- )
\ todo probably don't need dist
: dist     this - ;        \ ( a -- n )

compiler definitions
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
forth definitions

: ( next-char ')' = 0= if loop then ;
compiler definitions
: ( ( ; \ this comment is here to fix vim syntax highlight )
: \ \ ;
forth definitions

: :noname ( -- a ) 0 0 define here ['] docol @ , set-loop ] ;
compiler definitions
: [:      ( -- a ) lit, here 6 + , ['] jump , (later), ['] docol @ , ;
: ;]      ( a -- ) ['] exit , this! ;
forth definitions

: last  ( -- a )   current @ @ >cfa ;
: >does ( a -- a ) cell + ;
compiler definitions
: does> ( -- )     (lit), ['] last , ['] >does , ['] ! , ['] exit , this!
                   ['] docol @ , set-loop ;
forth definitions
: does> ( -- )     last :noname swap >does ! ;

: >value 2 cells + ;

: noop ( -- )        ;
: doer ( "name" -- ) create ['] noop cell + , does> @ >r ;
0 variable make*
compiler definitions
: make ( "name" -- ) (lit), lit, ' >value , ['] ! ,
                     here make* ! ['] exit , 0 , this! ;
: ;and ( -- )        ['] exit , ['] jump make* @ !+ this! ;
forth definitions
: make ( "name" -- ) :noname cell + ' >value ! ;
: undo ( "name" -- ) ['] noop cell + ' >value ! ;

\ todo maybe dont need values
: value ( n "name" -- ) create , does> @ ;
: to    ( n "name" -- ) ' >value ! ;
: +to   ( n "name" -- ) ' >value +! ;
compiler definitions
: to    ( "name" -- )   lit, ' >value , ['] ! , ;
: +to   ( "name" -- )   lit, ' >value , ['] +! , ;
forth definitions

: defer ( "name" -- )  create ['] noop , ['] exit , does> >r ;
: is    ( a "name" --) ' >value ! ;

: vocabulary ( "name" -- ) create 0 , does> context ! ;

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

: cstring ( | .*" -- ) (later), here string dist swap ! ;

: count   ( a -- a n ) @+ ;
: (data), ( -- a )     (lit), ['] jump , (later), swap this! ;

: d" ( | .*" -- ) here dup string h ! ;
: c" ( | .*" -- ) here dup cstring h ! ;
: s" ( | .*" -- ) [compile] c" count ;
compiler definitions
: d" ( | .*" -- ) (data), string align this! ;
: c" ( | .*" -- ) (data), cstring align this! ;
: s" ( | .*" -- ) [compile] c" ['] count , ;
forth definitions

: ." ( | .*" -- ) [compile] s" type ;
compiler definitions
: ." ( | .*" -- ) [compile] s" ['] type , ;
forth definitions

\ printing ===

: digit>char ( n -- n ) dup 10 < if '0' else 'W' then + ;

0 variable #start
: #len ( -- n )     pad #start @ - ;
: <#   ( -- )       pad #start ! ;
: #>   ( n -- a n ) drop #start @ #len ;
: hold ( n -- )     -1 #start +! #start @ c! ;
: #    ( n -- n )   base @ /mod digit>char hold ;
: #s   ( n -- n )   dup 0= if # else |: # dup if loop then then ;
: #pad ( c n -- )   dup #len > if over hold loop then 2drop ;
: h#   ( n -- n )   16 /mod digit>char hold ;

: u.pad ( n n c -- ) rot <# #s flip #pad #> type ;
: u.r   ( n n -- )   bl u.pad ;
: u.0   ( n n -- )   '0' u.pad ;
: u.    ( n -- )     <# #s #> type ;
: .     ( n -- )     u. space ;

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

compiler definitions
: [if]      [if] ;
: [then]    [then] ;
: [defined] [defined] ;
forth definitions

\ os ===

external sleep
external sleeps
external get-env
external cwd

external time-utc
\ todo get timezone and daylight savings somehow
-6 value hour-adj
: 24>12     12 mod dup 0= if drop 12 then ;
: time      time-utc flip hour-adj + 24 mod flip ;
: 00:#      # # drop ':' hold ;
: .time24   <# 00:# 00:# # # #> type ;
: .time12hm drop <# 00:# 24>12 # # #> type ;

external shell
: $ source-rest -leading 2dup shell ." exec: " type cr [compile] \ ;

external accept-file
: include source-rest 1/string source-len @ >in ! accept-file ;

\ floats ===

external f+
external f-
external f*
external f/
external f>str
external str>f

: fswap 2swap ;
: fdrop 2drop ;
: fdup  2dup ;

create fbuf 128 allot
: f. fbuf 128 f>str fbuf swap type ;

: F word str>f drop ;
compiler definitions
: F word str>f drop swap lit, , lit, , ;
forth definitions

: f, swap , , ;
: f@ @+ swap @ ;
: fconstant create f, does> f@ ;

\ todo this is messy
: u>f <# #s #> str>f drop ;

\ tags ===

: s>mem ( ... a n -- ) tuck s* @ 3 cells + -rot move s* +! ;

0 variable tags*
: tags, ( n -- )        cells >r ['] jump , (later), here swap r@ allot this! here tags* !
                        lit, , lit, r> , ['] s>mem , ;
: tag   ( n "name" -- ) create cells , does> @ tags* @ swap - cell - lit, , ['] @ , ;
compiler definitions
0 tag @0 1 tag @1 2 tag @2 3 tag @3
4 tag @4 5 tag @5 6 tag @6 7 tag @7
forth definitions

\ dynamic ===

external allocate
external allocate-page
external free
external reallocate
external dynsize
external dyn!
external dyn+!
external dyn@
external dync!
external dyn+c!
external dync@

external >dyn    \ ( s d h l -- )     copies from forth memory to dynamic memory
external dyn>    \ ( s h d l -- )     copies from dynamic memory to forth memory
external dynmove \ ( s sh d dh l -- ) copies between dynamic memory

\ ===


0 [if]
: postpone word cond
  2dup cvocab @ cfind ?dup if -rot 2drop >cfa , else
  2dup find           ?dup if -rot 2drop >cfa literal ['] , , else
    wnf
  endcond ;

: tags, ( n -- )        cells >r
                        (lit), lit, r@ , ['] s>mem , ['] jump , (later),
                        swap this! r> allot this! here tags* ! ;
[then]


\ blocks ===

: fill  ( a n n -- ) >r range check> if r@ swap c!+ loop then r> 3drop ;
: erase ( a n -- )   0 fill ;
: blank ( a n -- )   bl fill ;

\ : bthis-line 64 / 64 * ;
\ : bnext-line 64 + bthis-line ;
\ : \ blk @ if >in @ bnext-line >in ! else [compile] \ then ;
\ : line. swap 64 * + 64 range print. ;
\ : list. >r 16 0 u>?|: dup dup 2 u.r space r@ line. cr 1+ loop then r> 3drop ;
\ : list block list. ;

\ evaluate ===

: src@ source-ptr @ source-len @ >in @ ;
: src! >in ! source-len ! source-ptr ! ;

: evaluate src@ >r >r >r 0 src! interpret r> r> r> src! ;
