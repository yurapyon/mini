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
: column dup dup dup 3 u.r space h8. space ascii 2 spaces 32 + ;
: ashy 32 0 |: 2dup > if dup column column column column cr drop
  1+ loop then 2drop ;

\ : .k 1000 1024 */mod 1000 1024 */mod 1000 1024 */
\   <# # # # drop # # # drop # # # '.' hold #s #> type ;

: ./k 1000 1024 */ <# # # # '.' hold #s #> type ;

: blank bl fill ;

\ ===

: 24>12 12 mod dup 0= if drop 12 then ;

0 value hour-adj
: time time-utc flip hour-adj + flip ;
: 00: # # drop ':' hold ;
: .time24 <# 00: 00: # # #> type ;
: .time12hm drop <# 00: 24>12 # # #> type ;

: $ source-rest -leading 2dup shell
  ." exec: " type cr [compile] \ ;

: ?cr ( i width -- ) lastcol? if cr then ;

\ ===

[defined] block [if]

0 variable scr
: .line swap 64 * + 64 range .print ;
: .list >r 16 0 |: 2dup > if dup dup 2 u.r space r@ .line cr 1+
  loop then r> drop 2drop ;
: list dup scr ! dup . cr block .list ;

: scrbuf scr @ block ;

vocabulary editor
editor definitions

create e.find   0 , 64 allot
create e.insert 0 , 64 allot

: .editor
  ." b: " scr @ . cr
  ." f: " e.find count type '|' emit cr
  ." i: " e.insert count type '|' emit cr ;

: blank-line 64 blank ;
( addr len line -- )
: >line 2dup ! cell + dup blank-line swap move ;
: rest>line source-rest ?dup if 1 /string rot >line else
  drop then source nip >in ! ;

: >find> e.find dup rest>line count ;
: >insert> e.insert dup rest>line count ;

: l scr @ . cr scrbuf .list ;
: line# scrbuf swap 64 * + ;

0 variable chr
64 variable extent

: next-wrap bb.next-line 1024 mod ;

( chr -- )
: delete-line
  dup bb.next-line swap bb.this-line over 1024 swap -
  rot scrbuf + rot scrbuf + rot move
  15 line# blank-line ;

: .line# chr @ 64 / . ;
: t 16 mod 64 * chr ! scrbuf chr @ + 64 range .print space .line# cr ;
: p >insert> drop scrbuf chr @ bb.this-line + 64 move update ;
: u >insert> drop scrbuf chr @ next-wrap + 64 move update ;
: x scrbuf chr @ bb.this-line + 64 e.insert >line
  chr @ delete-line update ;

: k e.find e.insert 66 swapstrs ;
: wipe scrbuf 1024 bl fill update ;

forth definitions
editor

: l editor l ;
: t editor t ;

forth

[then]

\ ===

