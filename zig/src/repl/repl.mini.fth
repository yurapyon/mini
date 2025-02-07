32 constant bl
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

: h8.  <# h# h# #> type ;
: h16. <# h# h# h# h# #> type ;
: .bytes 2dup > if c@+ h8. space loop then 2drop ;

: dump range |: 2dup > if 16 split
    dup h16. space 2dup .bytes .print cr
  loop then 2drop ;

: .word name tuck type if space then ;
: words context @ @ |: ?dup if dup .word @ loop then ;

: s0 3 d" nulsohstxetxeotenqackbelbs ht lf vt ff cr so si " [] ;
: s1 3 d" dledc1dc2dc3dc4naksynetbcanem subescfs gs rs us " [] ;
: ascii cond dup 16 < if s0 type else dup 32 < if 16 - s1 type
  else dup 127 < if emit else drop ." del" endcond ;
: next dup dup dup 3 u.r space h8. space ascii 2 spaces 32 + ;
: ashy 32 0 |: 2dup > if dup next next next next cr drop 1+ loop
  then 2drop ;

\ : .k 1000 1024 */mod 1000 1024 */mod 1000 1024 */
\   <# # # # drop # # # drop # # # '.' hold #s #> type ;

: ./k 1000 1024 */ <# # # # '.' hold #s #> type ;

compiler definitions
: \" lit, 27 , ['] emit , [compile] ." ;
forth definitions

\ : \" 27 emit [compile] ." ;

: clr \" [2J" ;
: home \" [H" ;

: hide \" [?25l" ;
: show \" [?25h" ;

: clrterm clr home show ;

\ ===

0 value hour-adj
: time time-utc flip hour-adj + flip ;
: 00: # # drop ':' hold ;
: .time time <# 00: 00: # # #> type ;

\ ===

[defined] block [if]

0 variable scr
: .line swap 64 * + 64 range .print ;
: .list >r 16 0 |: 2dup > if dup dup 2 u.r space r@ .line cr 1+
  loop then r> drop 2drop ;
: list dup scr ! block .list ;

vocabulary editor
editor definitions

create efind 64 allot
create einsert 64 allot

: blank-line 64 bl fill ;

: rest-line >in @ dup source-len @ swap - ;

: read-line rest-line
  ?dup if 1- swap 1+ swap true else false then ;

: >insert> read-line if einsert blank-line
  einsert swap move then einsert 64 ;

: >find> read-line if efind blank-line
  efind swap move then efind 64 ;

: l bb.front .list ;
: line# bb.front swap 64 * + ;
: blank# line# blank-line update ;

0 value cx 0 value cy
: t 256 mod to cy 0 to cx cy line# 64 range .print space cy . cr ;
: p cy blank# ;


 : putc bb.front cy 64 * + cx + c! 1 +to cx ;
 : readp 2dup > if next-char putc 1+ loop then 2drop ;
 : p next-char source >in @ readp update 0 to cx ;
: wipe bb.front 1024 bl fill update ;

forth definitions
editor

' l
: l editor [ , ] ;

forth

[then]

\ ===

