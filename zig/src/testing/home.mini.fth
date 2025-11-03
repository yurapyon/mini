: dir-depth range 0 >r u>?|: c@+ '/' = if r> 1+ >r then loop then 2drop r> ;

create home-addr s" HOME" here 128 get-env
dup allot value home-len
: home home-addr home-len ;

create pwd-addr here 128 cwd
dup allot value pwd-len
: pwd pwd-addr pwd-len ;

home-addr pwd-addr home-len mem=
value under-home?

pwd dir-depth under-home? [if] home dir-depth - [then]
value pwd-depth

2 constant max-depth

: main
  \ root
  cond
    pwd-depth max-depth > if ." ..."  else
    under-home?           if '~' emit else
  endcond 

  \ pwd
  pwd-depth max-depth min >r
  pwd + |: 1- dup c@ '/' = if r> 1- >r then r@ if loop else r> drop then
  dup pwd + swap -
  type cr ;
