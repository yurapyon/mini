:noname
  2dup <= if
    2drop
  else
    dup c@ emit
    1+ recurse
  then ;

: type ( addr ct -- )
  over + swap [ , ] ;

: cr 10 emit ;

: ." [compile] s" type ; \ "

compiler
: ." [compile] s" type ; \ "
forth

\ ===

variable source-user-input

true source-user-input !

variable prompt-hook

: basic-prompt prompt-hook assign s" - " type ;

basic-prompt

: next-line
  source-user-input @ if prompt-hook @ execute then
  refill ;

: lookup find if >cfa execute true then ;

: to-number
  \ todo
  ;

: resolve
  2dup lookup    ?dup if [ exit, ] then
  \ 2dup to-number ?dup if exit then
  ." word not found: " type cr
  false ;

: interpret
  word ?dup if
    resolve
  else
    drop next-line
  then
  if recurse then ;

