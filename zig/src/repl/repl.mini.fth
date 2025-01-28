32 constant bl
10 constant nl
: space bl emit ;
: cr    nl emit ;
: print dup 32 126 within[] 0= if drop [char] . then emit ;

\ ( char ct -- )
: repeat ?dup if over emit 1- recurse then drop ;

: .chars 2dup > if c@+ emit recurse then 2drop ;
: type over + swap .chars ;

: ." [compile] s" count type ; \ "

compiler
: ." [compile] s" ['] count , ['] type , ; \ "
forth

\ ===

: .words ?dup if dup name tuck type if space then @ recurse then ;
: words wlatest .words ;

\ ===

: uwidth dup if base @ log then 1+ ;

8 cells allot
here @ constant tend
0 value tstart
: treset tend 1- to tstart ;
: tnext  -1 +to tstart ;

: u>temp base @ /mod digit>char tstart c! ?dup if tnext recurse then ;
: .temp  tend tstart .chars ;

\ ( u pad-ct char -- )
: .pad >r dup rot uwidth min - r> swap repeat ;

: u.  treset u>temp .temp ;
: u.r save       bl .pad u. ;
: u.0 save [char] 0 .pad u. ;

\ ===

: .bytes 2dup > if c@+ 2 u.0 space recurse then 2drop ;
: .print 2dup > if c@+       print recurse then 2drop ;
: .lines 2dup > if
    dup 16 + dup rot dup 4 u.r ." : " 2dup .bytes .print cr recurse
  then 2drop ;
: dump base @ >r hex over + swap .lines r> base ! ;

: .ks 1024 /mod swap u. ." ." u. ;

\ ===

:noname ." word not found: " type cr ; onwnf !
