\ str len -- char t/f
: check-char 3 = swap dup c@ ''' = swap 2 + c@ ''' = and and
  if drop 1+ c@ true else 0 false then ;

\ str len -- str len t/f
: check-negative 2dup drop c@ '-' = >r r@ if 1 /string then r> ;

\ str len -- str len base
: check-base over c@
   dup '%' = if drop 1 /string  2 else
   dup '#' = if drop 1 /string 10 else
       '$' = if      1 /string 16 else
     base @
   then then then ;

: >number 2dup check-char if true exit else drop then
  check-negative >r
  check-base >number,base if
    r> if negate then true
  else
    r> 2drop false
  then ;
