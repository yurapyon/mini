:noname 2dup > if c@+ emit recurse then ;
: type over + swap [ , ] 2drop ;

: bl 32 ;
: nl 10 ;
: space bl emit ;
: cr nl emit ;

:noname ?dup if over emit 1- recurse then ;
: repeat-char swap [ , ] drop ;

: pad-ct   tuck >r uwidth 0 r> clamp - ;
: pad-left -rot pad-ct swap repeat-char ;

: u.  >.buf .buf type ;
: u.r save       bl pad-left u. ;
: u.0 save [char] 0 pad-left u. ;

: ." [compile] s" count type ; \ "

compiler
: ." [compile] s" ['] count , ['] type , ; \ "
forth

: print-name name ?dup if type else drop ." _" then ;

: words ?dup if dup print-name space @ recurse then ;

: xt>def 2dup < if @ recurse then nip ;

: .inner ." (" cell + dup @ . ." )" ;

: print-body
  cond
    dup @ ['] exit =  if ." ;" return else
    dup @ ['] lit =   if ." lit" .inner else
    dup @ ['] jump =  if ." jump" .inner else
    dup @ ['] jump0 = if ." jump0" .inner else
    dup @ latest @ xt>def print-name
  endcond
  space cell + recurse ;

: see word find if
    dup print-name ." : "
    >cfa cell + print-body
  then cr ;

: printable? 32 126 within[] ;
: >printable dup printable? 0= if drop [char] . then ;

: print-header 4 u.r ." : " ;
: print-bytes 2dup > if c@+     2 u.0 space recurse then 2drop ;
: print-chars 2dup > if c@+ >printable emit recurse then 2drop ;
: print-line dup print-header 2dup print-bytes print-chars ;

:noname 2dup > if dup 16 + swap save print-line cr recurse then ;
: dump base @ >r hex over + swap [ , ] r> base ! ;

quit

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

