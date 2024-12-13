
:noname 2dup > if c@+ emit recurse then ;
: type over + swap [ , ] 2drop ;

: bl 32 ;
: nl 10 ;
: space bl emit ;
: cr nl emit ;

: ." [compile] s" count type ; \ "

compiler
: ." [compile] s" ['] count , ['] type , ; \ "
forth

: print-name name ?dup if type else drop ." _" then ;

:noname ?dup if dup print-name space @ recurse then ;
: words latest @ [ , ] ;

:noname 2dup < if @ recurse then ;
: xt>def latest @ [ , ] nip ;

: .inner ." (" cell + dup @ . ." )" ;

:noname
  cond
    dup @ ['] exit =  if ." ;" return else
    dup @ ['] lit =   if ." lit" .inner else
    dup @ ['] jump =  if ." jump" .inner else
    dup @ ['] jump0 = if ." jump0" .inner else
    dup @ xt>def print-name
  endcond
  space cell + recurse ;

: print-body >cfa cell + [ , ] ;

: see word find if dup print-name ." : " print-body then cr ;

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

