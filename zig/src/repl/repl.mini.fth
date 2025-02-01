32 constant bl
: space bl emit ;
: spaces 0 ` 2dup > if space 1+ goto` then 2drop ;
: cr 10 emit ;
: print dup 32 < over 126 > or if drop [char] . then emit ;
: .print 2dup > if c@+ print recurse then 2drop ;
: .chars 2dup > if c@+ emit recurse then 2drop ;
: type range .chars ;
compiler
: ." [compile] s" ['] count , ['] type , ;
forth
:noname type [char] ? emit cr ; onwnf !

: u. <# #s #> type ;
: u.pad rot <# #s flip #pad #> type ;
: u.r bl u.pad ;
: u.0 [char] 0 u.pad ;
: . u. space ;
: ? @ . ;

: b. <# h# h# #> type ;
: c. <# h# h# h# h# #> type ;
: .bytes 2dup > if c@+ b. space recurse then 2drop ;

: dump range ` 2dup > if 16 split
    dup c. space 2dup .bytes .print cr
  goto` then 2drop ;

: words wlatest ` ?dup if dup name tuck type if space then @
  goto` then ;

: s0 3 d" nulsohstxetxeotenqackbelbs ht lf vt ff cr so si " [] ;
: s1 3 d" dledc1dc2dc3dc4naksynetbcanem subescfs gs rs us " [] ;
: ascii cond dup 16 < if s0 type else dup 32 < if 16 - s1 type
  else dup 127 < if emit else drop ." del" endcond ;
: next dup dup dup 3 u.r space b. space ascii space space 32 + ;
: ashy 32 0 ` 2dup > if dup next next next next cr drop 1+ goto`
  then 2drop ;

\ : .k 1000 1024 */mod 1000 1024 */mod 1000 1024 */
\   <# # # # drop # # # drop # # # [char] . hold #s #> type ;

: .k 1000 1024 */ <# # # # [char] . hold #s #> type ;

[defined] block [if]
: .line swap 64 * + 64 range .print ;
: .list >r 16 0 ` 2dup > if dup dup 2 u.r space r@ .line cr 1+
  goto` then r> drop 2drop ;
: list block .list ;

\ editor

: l b0 .list ;
0 value cx
0 value cy
: t 0 to cx to cy cy b0 .line space cy . cr ;
: putc b0 cy 64 * + cx + c! 1 +to cx ;
: readp 2dup > if next-char putc 1+ recurse then 2drop ;
: p next-char source >in @ readp update ;
: wipe bl swap block 1024 range fill update ;

[then]
