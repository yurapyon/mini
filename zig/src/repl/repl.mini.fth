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
