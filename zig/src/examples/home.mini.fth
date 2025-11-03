\ pwd formatter

: fsdepth range 0 -rot u>?|: c@+ '/' = if rot 1+ -rot then loop then 2drop ;

create home-addr s" HOME" here 128 get-env
dup allot constant home-len
: home home-addr home-len ;

create pwd-addr here 128 cwd
dup allot constant pwd-len
: pwd pwd-addr pwd-len ;

home pwd-addr swap mem= constant in-home?

pwd fsdepth in-home? [if] home fsdepth - [then]
constant pwd-depth

2 constant max-depth

: main
  \ root
  cond
    pwd-depth max-depth > if ." ..."  else
    in-home?              if '~' emit else
  endcond 

  \ pwd
  pwd-depth max-depth min pwd +
  |: 1- dup c@ '/' = if swap 1- swap then over if loop then nip
  dup pwd + swap - type ;
