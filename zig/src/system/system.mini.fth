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

( r g b idx -- )
: ppalette! 3 * tuck 2 + pcolors! tuck 1 + pcolors! pcolors! ;

hex
00 00 00 0 ppalette!
00 00 ff 1 ppalette!
00 ff 00 2 ppalette!
ff 00 00 3 ppalette!
00 ff ff 4 ppalette!
ff ff 00 5 ppalette!
ff 00 ff 6 ppalette!
ff ff ff 7 ppalette!
40 40 40 8 ppalette!
40 40 a0 9 ppalette!
40 a0 40 a ppalette!
a0 40 40 b ppalette!
40 a0 a0 c ppalette!
a0 a0 40 d ppalette!
a0 40 a0 e ppalette!
a0 a0 a0 f ppalette!
decimal

0 variable cursor

: blline >r
  640 0 |: 2dup u> if dup r@ cursor @ pset 1+ loop then 2drop
  r> drop ;

: row
  dup cursor !
  8 *
     dup blline
  1+ dup blline
  1+ dup blline
  1+ dup blline
  1+ dup blline
  1+ dup blline
  1+ dup blline
  1+     blline ;

hex
0 row
1 row
2 row
3 row
4 row
5 row
6 row
7 row
8 row
9 row
a row
b row
c row
d row
e row
f row
decimal

: on-key 1 = if emit then ;
' on-key 0 setxt

0 variable mx
0 variable my
false variable m0-held

: on-mouse-move my ! mx !
m0-held @ if mx @ . my @ . cr then
;
' on-mouse-move 1 setxt

( value mods -- )
: on-mouse-down
drop dup $7 and 0= if $10 and m0-held ! else drop then ;
' on-mouse-down 2 setxt

: frame
  ;

: main frame draw/poll close? 0= if loop then deinit ;

main

bye

\ todo this is just debug stuff

: emit __emit ;
: space bl emit ;
: spaces 0 |: 2dup > if space 1+ loop then 2drop ;
: cr 10 emit ;
: printable 32 126 in[,] ;
: print dup printable 0= if drop '.' then emit ;
: .print 2dup > if c@+ print loop then 2drop ;
: .chars 2dup > if c@+ emit loop then 2drop ;
: type range .chars ;
: ." [compile] s" type ;
compiler definitions
: ." [compile] s" ['] type , ;
forth definitions
:noname type '?' emit cr ; onwnf !

: u. <# #s #> type ;
: u.pad rot <# #s flip #pad #> type ;
: u.r bl u.pad ;
: u.0 '0' u.pad ;
: . u. space ;
: ? @ . ;

: .2 swap . . ;
: .3 flip . . . ;

\ ===

: pixels!+ tuck pixels! 1+ ;

: setpal >r flip r> 3 * pixels!+ pixels!+ pixels!+ drop ;

: debug-line >r
  640 0 |: 2dup > if dup 30 r@ + r@ putp 1+ loop then 2drop
  r> drop ;

: gray dup dup 16 255 keepin ;

: % 255 100 */ ;

: default-palette 0 % gray 0 setpal
  20 % gray 1 setpal 60 % gray 2 setpal 100 % gray 3 setpal
  [ hex ]
  00 00 f0 4 setpal 00 f0 00 5 setpal f0 00 00 6 setpal
  00 f0 f0 7 setpal f0 f0 00 8 setpal f0 00 f0 9 setpal
  00 60 c0 a setpal 60 c0 00 b setpal c0 00 60 c setpal
  40 80 f0 d setpal 80 f0 40 e setpal f0 40 80 f setpal
  [ decimal ] ;

: blline >r
  640 0 |: 2dup > if dup r@ 1 putp 1+ loop then 2drop
  r> drop ;

: thing
  \ 16 0 |: 2dup > if dup debug-line 1+ loop then 2drop
  400 0 |: 2dup > if dup blline 1+ loop then 2drop
  v-up
  ;

  default-palette
  \ thing

: putc 2 * 2584 + characters! ;
: puta 2 * 2585 + characters! ;
: puts 24 + characters! ;
: putsprite 16 i>xy 160 * + >r
160 0 do.u> rot over r@ + puts 16 + godo 2drop
r> drop
;

hex
00 00 00 00 00 00 00 00 00 00
decimal
0 putsprite

hex
00 82 82 82 fe 42 22 12 0a 06
decimal
255 putsprite


0 0 putc
0b00010111 0 puta

20 1 putc
2  1 puta

0 2 putc
0b00000011 2 puta

1 80 putc
0b00000011 80 puta

2 160 putc
0b00000011 160 puta
v-up

0 [if]

: fillpage >r
  0xffff 0 |: 2dup u> if third over r@ putp 1+ loop then 2drop
  r> 2drop ;
: fillscr dup 0 fillpage 1 fillpage ;
: blankscr 0 fillscr ;

: fillline
  ;

: defchars
  d" \x0f\x3f\xff\xff\x3f\x0f" 0 setchar
  d" \x08\x48\x88\x88\x48\x08" 1 setchar
  ;

: defpal [ hex ]
  00 00 00 0 setpal ff ff ff 1 setpal 80 80 80 2 setpal
  00 00 ff 2 setpal 00 ff 00 3 setpal ff 00 00 4 setpal
  00 ff ff 5 setpal ff ff 00 6 setpal ff 00 ff 7 setpal
  [ decimal ] ;

: init-video defchars defpal blankscr v-up ;

\ todo show boot image

[then]
