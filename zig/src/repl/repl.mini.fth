: space bl emit ;
: spaces 0 do.u> space 1+ godo 2drop ;
: cr 10 emit ;
: print dup printable 0= if drop '.' then emit ;
: .print do.u> c@+ print godo 2drop ;
: .chars do.u> c@+  emit godo 2drop ;
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

: .byte  <# h# h# #> type ;
: .short <# h# h# h# h# #> type ;
: .bytes do.u> c@+ .byte space godo 2drop ;

: dump range do.u> 16 split dup .short space 2dup .bytes .print
  cr godo 2drop ;

: .word name tuck type if space then ;
: words context @ @ do.?dup dup .word @ godo ;

: .ascii dup printable if emit else ctlcode type then ;
: .col dup 3 u.r space dup .byte space .ascii 2 spaces ;
: .row 128 range do.u> dup .col 32 + godo 2drop ;
: ashy 32 0 do.u> dup .row cr 1+ godo 2drop ;

\ : .k 1000 1024 */mod 1000 1024 */mod 1000 1024 */
\   <# # # # drop # # # drop # # # '.' hold #s #> type ;

: ./k 1000 1024 */ <# # # # '.' hold #s #> type ;

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
: .list >r 16 0 do.u> dup dup 2 u.r space r@ .line cr 1+
  godo r> drop 2drop ;
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
: t 16 mod 64 * chr ! scrbuf chr @ + 64 range .print space
  .line# cr ;
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
