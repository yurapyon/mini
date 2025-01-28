
here @
: within[] rot tuck >= -rot <= and ;
: char>digit cond
    dup [char] 0 [char] 9 within[] if [char] 0 -      else
    dup [char] A [char] Z within[] if [char] A - 10 + else
    dup [char] a [char] z within[] if [char] a - 10 + else
  endcond ;

dist . cr

here @
: char>digit
  dup [char] 0 >= if [char] 0 - then
  dup 17 >= if  7 - then
  dup 42 >= if 32 - then ;
dist . cr

here @
: char>digit cond
  dup [char] 9 <= if [char] 0 - else
  dup [char] Z <= if [char] 7 - else
  dup [char] z <= if [char] W - else
  endcond ;
dist . cr
