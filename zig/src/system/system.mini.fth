: \ source-len @ >in ! ;

: forth fvocab context ! ;
: compiler cvocab context ! ;
: definitions context @ current ! ;

compiler definitions
: literal lit, , ;
: [compile] ' , ;
: ['] ' [compile] literal ;
forth definitions

: constant word define ['] docon @ , , ;
: enum dup constant 1+ ;
: flag dup constant 1 lshift ;
: create word define ['] docre @ , ['] exit , ;
: variable create , ;

0 variable loop*
: set-loop here loop* ! ;
compiler definitions
: |: set-loop ;
: loop ['] jump , loop* @ , ;
forth definitions
: : : set-loop ;

: (later), here 0 , ;
: (lit), lit, (later), ;
: this here swap ;
: this! this ! ;
: dist this - ;
compiler definitions
: if ['] jump0 , (later), ;
: else ['] jump , (later), swap this! ;
: then this! ;

: u>?|: [compile] |: ['] 2dup , ['] u> , [compile] if ;
: dup?|: [compile] |: ['] dup , [compile] if ;
0 constant cond
: endcond dup?|: [compile] then loop then drop ;
forth definitions

: ( next-char ')' = 0= if loop then ;
compiler definitions
: ( ( ; \ )
: \ \ ;
forth definitions

\ noname/does ===

: :noname 0 0 define here ['] docol @ , set-loop ] ;
compiler definitions
: [: lit, here 6 + , ['] jump , (later), ['] docol @ , ;
: ;] ['] exit , this! ;
forth definitions

: last current @ @ >cfa ;
: >does cell + ;
compiler definitions
: does> (lit), ['] last , ['] >does , ['] ! , ['] exit ,
  this! ['] docol @ , set-loop ;
forth definitions
: does> last :noname swap >does ! ;

: cells cell * ;

: value create , does> @ ;
: vname ' 2 cells + ;
: to vname ! ;
: +to vname +! ;
compiler definitions
: to lit, vname , ['] ! , ;
: +to lit, vname , ['] +! , ;
forth definitions

: vocabulary create 0 , does> context ! ;

0 constant s[
: ]s constant ;
: +field over create , + does> @ + ;
: field swap aligned swap +field ;

\ ===

: 2swap >r flip r> flip ;

: binary 2 base ! ;
: hex 16 base ! ;
: decimal 10 base ! ;

: <> = 0= ;
: min 2dup > if swap then drop ;
: max 2dup < if swap then drop ;

-1 enum %lt enum %eq constant %gt
: compare 2dup = if 2drop %eq else > if %gt else %lt then then ;

\ ( value min max -- value )
: clamp rot min max ;
: in[,] rot tuck >= -rot <= and ;
: in[,) 1- in[,] ;

: @+ dup cell + swap @ ;
: !+ tuck ! cell + ;
: c@+ dup 1+ swap c@ ;
: c!+ tuck c! 1+ ;

: split over + tuck swap ;
: (data), (lit), ['] jump , (later), swap this! ;
: next-digit next-char char>digit ;
: next-byte next-digit 16 * next-digit + ;
: escape, next-char cond
  dup '0' = if drop 0 c, else
  dup 't' = if drop 9 c, else
  dup 'n' = if drop 10 c, else
  dup 'N' = if drop 10 c, refill drop else
  dup 'x' = if drop next-byte c, else
  dup '&' = if drop refill drop else
    c,
  endcond ;

: string next-char drop |: next-char cond dup '"' = if drop exit else
  dup '\' = if drop escape, else c, endcond loop ;

: cstring (later), here string dist swap ! ;
: d" here dup string h ! ;
: c" here dup cstring h ! ;
: count @+ ;
: s" [compile] c" count ;
compiler definitions
: d" (data), string align this! ;
: c" (data), cstring align this! ;
: s" [compile] c" ['] count , ;
forth definitions

: space bl emit ;
: cr    10 emit ;

: digit>char dup 10 < if '0' else 'W' then + ;
0 variable #start
: #len pad #start @ - ;
: <# pad #start ! ;
: #> drop #start @ #len ;
: hold -1 #start +! #start @ c! ;
: # base @ /mod digit>char hold ;
: #s dup 0= if # else |: # dup if loop then then ;
: #pad dup #len > if over hold loop then 2drop ;
: h# 16 /mod digit>char hold ;
: u.pad rot <# #s flip #pad #> type ;
: u.r bl u.pad ;
: u.0 '0' u.pad ;
: u. <# #s #> type ;
: . u. space ;
: printable 32 126 in[,] ;
: print dup printable 0= if drop '.' then emit ;
: byte. <# h# h# #> type ;
: short. <# h# h# h# h# #> type ;
: print. u>?|: c@+ print loop then 2drop ;
: line. swap 64 * + 64 range print. ;
: list. >r 16 0 u>?|: dup dup 2 u.r space r@ line. cr 1+ loop then r> 3drop ;
\ : list block list. ;
: sdata s* @ s0 over - ;
: depth sdata nip cell / ;
: cells. swap cell - |: 2dup u<= if dup @ . cell - loop then 2drop ;
: <.> <# '>' hold #s '<' hold #> type ;
: .s depth <.> space sdata range cells. ;
\ todo rename []
: [] flip over * rot + swap ;
: spaces 0 u>?|: space 1+ loop then 2drop ;
: ctlcode cond dup 32 u< if 3
d" nulsohstxetxeotenqackbelbs ht lf vt ff cr so si dledc1dc2dc3dc4naksynetbcanem subescfs gs rs us "
[] else 127 = if s" del" else 0 0 endcond ;
: bytes. u>?|: c@+ byte. space loop then 2drop ;
: dump range u>?|: 16 split dup short. space 2dup bytes. print. cr loop then 2drop ;
: word. name tuck type if space then ;
: words context @ @ dup?|: dup word. @ loop then drop ;
: ascii. dup printable if emit else ctlcode type then ;
: col. dup 3 u.r space dup byte. space ascii. 2 spaces ;
: row. 128 range u>?|: dup col. 32 + loop then 2drop ;
: ashy 32 0 u>?|: dup row. cr 1+ loop then 2drop ;
: fill >r range u>?|: r@ swap c!+ loop then r> 3drop ;
: erase 0 fill ;
: blank bl fill ;

: ." [compile] s" type ;
compiler definitions
: ." [compile] s" ['] type , ;
forth definitions

\ : bthis-line 64 / 64 * ;
\ : bnext-line 64 + bthis-line ;
\ : \ blk @ if >in @ bnext-line >in ! else [compile] \ then ;

( os externals )
external time-utc
-6 value hour-adj
: 24>12 12 mod dup 0= if drop 12 then ;
: time time-utc flip hour-adj + 24 mod flip ;
: 00:# # # drop ':' hold ;
: time24. <# 00:# 00:# # # #> type ;
: time12hm. drop <# 00:# 24>12 # # #> type ;
external shell
: $ source-rest -leading 2dup shell ." exec: " type cr [compile] \ ;
external accept-file
: include source-rest 1 /string source-len @ >in ! accept-file ;

\ ===

external setxt
external close?
external draw/poll
external deinit
external pcolors!
external pcolors@
external pset
external pline
external prect
external pbrush!
external pbrush@
external pbrush
external pbrushline

: region create >r >r >r , r> , r> , r> , ;
: region>stack @+ swap @+ swap @+ swap @ ;

( x y x0 y0 x1 y1 -- t/f )
: inside? >r swap >r rot >r in[,) r> r> r> in[,) and ;

0 variable c.0
1 variable c.1
0 variable c.sel

: c.adv dup @ 1+ 16 mod swap ! ;

: c.toggle c.sel @ 0= c.sel ! ;

: c.current c.sel @ 0= if c.0 else c.1 then ;

 0 0 25 25 region c.0.view
25 0 50 25 region c.1.view

: c.draw
  c.0.view region>stack c.0 @ prect
  c.1.view region>stack c.1 @ prect ;

: c.click
  2dup c.0.view region>stack inside? if 2drop c.0 c.adv else
       c.1.view region>stack inside? if       c.1 c.adv else
  then then ;

( r g b idx -- )
: ppalette! 3 * tuck 2 + pcolors! tuck 1 + pcolors! pcolors! ;

hex
00 00 00 $0 ppalette!
ff ff ff $1 ppalette!
00 00 ff $2 ppalette!
00 ff 00 $3 ppalette!
ff 00 00 $4 ppalette!
00 ff ff $5 ppalette!
ff ff 00 $6 ppalette!
ff 00 ff $7 ppalette!
40 40 40 $8 ppalette!
40 40 a0 $9 ppalette!
40 a0 40 $a ppalette!
a0 40 40 $b ppalette!
40 a0 a0 $c ppalette!
a0 a0 40 $d ppalette!
a0 40 a0 $e ppalette!
a0 a0 a0 $f ppalette!
decimal

0 0 640 400 1 prect

: setupbrush 49 0 u>?|: 0 over pbrush! 1+ loop then ;

setupbrush

0 variable mx
0 variable my
0 variable mx-last
0 variable my-last
false variable m0-held

\ : hovered? mx @ my @ rot region>stack inside? ;

: drawline mx @ my @ mx-last @ my-last @ c.current @ pbrushline ;

: on-key 1 = if 'X' = if c.toggle then then ;

: on-mouse-move mx @ mx-last ! my @ my-last ! my ! mx !
  m0-held @ if drawline
  then ;

( value mods -- )
: on-mouse-down drop dup $7 and 0= if $10 and dup m0-held !
  if mx @ my @ c.click then
  drawline
  else drop then ;

' on-key 0 setxt
' on-mouse-move 1 setxt
' on-mouse-down 2 setxt

: frame c.draw ;

: main frame draw/poll close? 0= if loop then deinit ;

main
