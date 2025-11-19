\ ===

0 [if]
: array.cap create allocate , 0 , ;
: array 0 array.cap ;

: a.ptr  ( a -- n )    @ ;
: a.cap  ( a -- n )    @ dynsize ;
: >a.len ( a -- addr ) cell + ;

: a.grow ( size a -- )
  tuck >a.len @ + over a.cap ( a new-len cap )
  over < if 2 * swap a.ptr reallocate else 2drop then ;

: a.fit  ( a -- )
  dup >a.len @ over a.cap ( a len cap )
  over > if swap a.ptr reallocate else 2drop then ;

: a.new  ( size a -- addr ) 2dup a.grow dup >a.len @ -rot >a.len +! ;
: a.drop ( size a -- addr ) swap negate swap tuck >a.len +! >a.len @ ;

: a, ( val a -- ) cell over a.new swap a.ptr dyn! ;
[then]

\ ===

: a.cap   dynsize cell - ;
: a.len@  0 swap dyn@ ;
: a.len!  0 swap dyn! ;
: a.len+! 0 swap dyn+! ;

: .a dup . dup a.len@ . a.cap . ;

: <array>,cap cell + allocate 0 over a.len! ;
: <array>     0 <array>,cap ;

: a.grow ( size a -- )
  tuck a.len@ + over a.cap ( a new-len cap )
  over < if 2 * cell + swap reallocate else 2drop then ;

: a.fit  ( a -- )
  dup a.len@ over a.cap ( a len cap )
  over > if cell + swap reallocate else 2drop then ;

: a.new  ( size a -- addr ) 2dup a.grow dup a.len@ cell + -rot a.len+! ;
: a.drop ( size a -- addr ) swap negate swap tuck a.len+! a.len@ cell + ;

\ ===

: push ( val a -- ) cell over a.new  swap dyn! ;
: pop  ( a -- val ) cell over a.drop swap dyn@ ;

: pushc ( val a -- ) 1 over a.new  swap dync! ;
: popc  ( a -- val ) 1 over a.drop swap dync@ ;

\ : a! a.ptr dyn! ;
\ : a@ a.ptr dyn@ ;

<array> constant test
test .a cr

0 test push
1 test push
2 test push

.s cr

test pop . test a.len@ . cr
test pop . test a.len@ . cr
test pop . test a.len@ . cr

test a.len@ . test a.cap . cr
test a.fit
test a.len@ . test a.cap . cr

.s cr

0 test pushc
1 test pushc
2 test pushc

test popc . test a.len@ . cr
test popc . test a.len@ . cr
test popc . test a.len@ . cr

test a.len@ . test a.cap . cr
test a.fit
test a.len@ . test a.cap . cr

