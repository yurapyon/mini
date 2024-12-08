
:noname 2dup > if c@+ emit recurse then ;
: type over + swap [ , ] 2drop ;

: bl 32 ;
: nl 10 ;
: space bl emit ;
: cr nl emit ;

: ." [compile] s" type ; \ "

compiler
: ." [compile] s" ['] type , ; \ "
forth

: print-name cell + c@+ ?dup if type else drop then ;

:noname ?dup if dup print-name space @ recurse then ;
: words latest @ [ , ] ;

\ ===

variable source-user-input

true source-user-input !

variable prompt-hook

: basic-prompt prompt-hook assign ." > " ;

basic-prompt

: next-line
  source-user-input @ if prompt-hook @ execute then
  refill ;

: lookup find if >cfa execute true then ;

: resolve
  cond
  2dup lookup  if 2drop else
  2dup >number if 2drop else
  ." word not found: " type cr
  endcond ;

: interpret
  word ?dup if
    resolve
  else
    drop next-line 0= if return then
  then
  recurse ;

