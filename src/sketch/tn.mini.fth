: str>char 3 = >r c@+ ''' = >r c@+ swap c@ ''' = r> r> and and ;

\ str len -- str len t/f
: str>neg over c@ '-' = if 1 /string true else false then ;

\ str len -- str len base
: str>base over c@
   dup '%' = if drop 1 /string  2 else
   dup '#' = if drop 1 /string 10 else
       '$' = if      1 /string 16 else
     base @
   then then then ;

: pad here 64 + ;

: in[,] rot tuck >= -rot <= and ;

: char>digit
    dup '0' '9' in[,] if '0' - else
    dup 'A' 'Z' in[,] if '7' - else
    dup 'a' 'z' in[,] if 'W' - else
  then then then ;

( str len base -- number t/f )
: str>number 0 pad ! >r range |: 2dup u> if
    dup c@ char>digit dup r@ < if r@ pad @ * + pad ! 1+ loop else 2drop then
  then r> drop = pad @ swap ;

: >number 2dup str>char if -rot 2drop true exit else drop then
  str>neg >r str>base str>number if
    r> if negate then true
  else
    r> drop false
  then ;
