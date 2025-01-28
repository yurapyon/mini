32 constant bl : space bl emit ; : cr 10 emit ; : print dup 32 126 within[] 0=
if drop [char] . then emit ; : .chars 2dup > if c@+ emit recurse then 2drop ;
: type over + swap .chars ; compiler : ." [compile] s" ['] count , ['] type , ;
forth :noname ." word not found: " type cr ; onwnf ! 8 cells allot here @
constant tend 0 value tstart : u>temp base @ /mod digit>char tstart c! ?dup if
-1 +to tstart recurse then ; : u. tend 1- to tstart u>temp tend tstart .chars ;
: uwidth dup if base @ log then 1+ ; : emits ?dup if over emit 1- recurse then
drop ; : .pad >r dup rot uwidth min - r> swap emits ; : u.r save bl .pad u. ;
: u.0 save [char] 0 .pad u. ; : . u. space ; : .bytes 2dup > if c@+ 2 u.0 space
recurse then 2drop ; : .print 2dup > if c@+ print recurse then 2drop ; : .lines
2dup > if dup 16 + dup rot dup 4 u.r ." : " 2dup .bytes .print cr recurse
then 2drop ; : dump base @ >r hex over + swap .lines r> base ! ; : .words
?dup if dup name tuck type if space then @ recurse then ; : words wlatest .words ;
