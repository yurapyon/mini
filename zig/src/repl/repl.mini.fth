: bl 32 ;
: nl 10 ;
: space bl emit ;
: cr nl emit ;

: .chars 2dup > if c@+ emit recurse then 2drop ;
: type over + swap .chars ;

: ." [compile] s" count type ; \ "

compiler
: ." [compile] s" ['] count , ['] type , ; \ "
forth

\ ===

: .name name ?dup if type else drop ." _" then ;
: .words ?dup if dup .name space @ recurse then ;
: words wlatest .words ;

\ ===

: uwidth dup if base @ log then 1+ ;
: chop base @ /mod ;

8 cells allot
here @ constant temp-end
variable temp-start

: reset-temp temp-end 1- temp-start ! ;
: next-temp -1 temp-start +! ;
: temp! temp-start @ c! ;

: >temp chop digit>char temp! ?dup if next-temp recurse then ;
: .temp temp-end temp-start @ .chars ;

\ ( char ct -- )
: repeat ?dup if over emit 1- recurse then drop ;

\ ( u pad-ct char -- )
: .pad >r
    tuck >r uwidth 0 r> clamp -
  r> swap repeat ;

: u.  reset-temp >temp .temp ;
: u.r save       bl .pad u. ;
: u.0 save [char] 0 .pad u. ;

\ ===

: >printable dup 32 126 within[] 0= if drop [char] . then ;

: .bytes     2dup > if c@+     2 u.0 space recurse then 2drop ;
: .printable 2dup > if c@+ >printable emit recurse then 2drop ;
: .lines
  2dup > if
    dup 16 + swap save dup 4 u.r ." : " 2dup .bytes .printable cr
    recurse
  then 2drop ;

: dump
  base @ >r
  hex over + swap .lines
  r> base ! ;

: .ks 1024 /mod swap u. ." ." u. ;

quit

\ ===

\ todo note
\ if interpret/import is defined,
\ quit has to be redefined in forth

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

