32 constant bl
: space bl emit ;
: spaces 0 |: 2dup > if space 1+ loop then 2drop ;
: cr 10 emit ;
: printable 32 126 in[,] ;
: print dup printable 0= if drop '.' then emit ;
: .print 2dup > if c@+ print loop then 2drop ;
: .chars 2dup > if c@+ emit loop then 2drop ;
: type range .chars ;
compiler
: ." [compile] s" ['] type , ;
forth
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

: words wlatest |: ?dup if dup name tuck type if space then @
  loop then ;

: s0 3 d" nulsohstxetxeotenqackbelbs ht lf vt ff cr so si " [] ;
: s1 3 d" dledc1dc2dc3dc4naksynetbcanem subescfs gs rs us " [] ;
: ascii cond dup 16 < if s0 type else dup 32 < if 16 - s1 type
  else dup 127 < if emit else drop ." del" endcond ;
: next dup dup dup 3 u.r space h8. space ascii 2 spaces 32 + ;
: ashy 32 0 |: 2dup > if dup next next next next cr drop 1+ loop
  then 2drop ;

\ : .k 1000 1024 */mod 1000 1024 */mod 1000 1024 */
\   <# # # # drop # # # drop # # # '.' hold #s #> type ;

: .k 1000 1024 */ <# # # # '.' hold #s #> type ;

[defined] block [if]
: .line swap 64 * + 64 range .print ;
: .list >r 16 0 |: 2dup > if dup dup 2 u.r space r@ .line cr 1+
  loop then r> drop 2drop ;
: list block .list ;

\ editor

: l blk .list ;
0 value cx
0 value cy
: t 0 to cx to cy cy blk .line space cy . cr ;
: putc blk cy 64 * + cx + c! 1 +to cx ;
: readp 2dup > if next-char putc 1+ loop then 2drop ;
: p next-char source >in @ readp update ;

[then]
