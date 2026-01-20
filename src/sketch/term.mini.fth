compiler definitions
: \" lit, 27 , ['] emit , [compile] ." ;
forth definitions

\ : \" 27 emit [compile] ." ;

: clr \" [2J" ;
: home \" [H" ;

: hide \" [?25l" ;
: show \" [?25h" ;

: clrterm clr home show ;
