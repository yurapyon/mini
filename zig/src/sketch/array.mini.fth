: array create 0 allocate , 0 , ;

: a.ptr @ ;
: a.cap @ dynsize ;
: >a.len cell + ;

: a.grow ( len a -- ) 2dup a.cap > if a.ptr reallocate else 2drop then ;
: a.fit  ( a -- )     dup >a.len @ swap a.ptr reallocate ;

: a.new  ( size a -- addr ) >r
  r@ >a.len @ over + 2 * r@ a.grow
  r@ >a.len @ swap r> >a.len +! ;

: a.drop ( size a -- addr )
  swap negate over >a.len +! dup >a.len @ swap a.ptr dyn@ ;

\ ===

: push ( val a -- ) cell over a.new swap a.ptr dyn! ;
: pop  ( a -- val ) cell swap a.drop ;

: a! a.ptr dyn! ;
: a@ a.ptr dyn@ ;

array test
test a.cap . cr

0 test push
1 test push
2 test push

0 test pop .
test >a.len @ . cr
2 test pop .
test >a.len @ . cr
4 test pop .
test >a.len @ . cr

test >a.len @ . test a.cap . cr
test a.fit
test >a.len @ . test a.cap . cr

