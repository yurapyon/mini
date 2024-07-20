: k 1024 * ;

: memmap
  over + swap
  create ,
  does> @ ;

\ ===

: `cell 2 ;
: `cells `cell * ;
: `c!
  2dup c!
  swap 8 rshift swap 1 + c! ;
: `c@
  ;
: `c+!
  ;

\ ===

0 `cell +field >stk-mem
  `cell +field >stk-size
  `cell +field >stk-top
constant stack

: <stack> >r
      r@ >stk-size `c!
  dup r@ >stk-mem `c!
      r> >stk-top `c! ;

: spush >r
  r@ >stk-top @ `c!
  r> >stk-top `cell swap `c+! ;

: spop
  ;

: sdrop spop drop ;
: sdup dup spop swap 2dup spush spush ;

\ ===

128 `cells constant |s|sz
128 `cells constant |r|sz

create mmem 32 k allot
: m! mmem + `c! ;
: m@ mmem + `c@ ;

0 `cell memmap mpc
  stack memmap |s|
  |s|sz memmap |s|mem
  stack memmap |r|
  |r|sz memmap |r|mem
  `cell memmap mhere
  `cell memmap mlatest
  `cell memmap mstate
constant mdict-start

|s|mem |s|sz |s| <stack>
|r|mem |r|sz |s| <stack>
mdict-start mhere m!
0 mlatest m!
0 mstate m!

\ ===

create builtins 127 cells allot
0 value builtins-ct

: builtin
  builtins builtins-ct cells + ,
  builtins-ct constant
  1 +to builtins-ct ;

:noname ;
builtin `nop

:noname
  mpc `cell + @ |s| spush
  mpc `cell pc +! ;
  ;
builtin `lit

:noname |s| sdrop ;
builtin `drop

:noname |s| sdup ;
builtin `dup

\ ===

: .mmem-status
  ."    mdict start: " mdict-start . cr
  ." builtins count: " builtins-ct . cr
  ;

\ ===

.mmem-status
