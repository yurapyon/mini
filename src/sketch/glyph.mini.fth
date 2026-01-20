0 value baddr
0 value selected

: sel baddr selected + ;
: .pixel if [char] * emit else space then ;
: .row  >r sel 6 range ` 2dup > if dup c@ r@ lshift 0x80 and .pixel 1+ goto` then r> 3drop ;
: .rows 8 0 ` 2dup > if dup .row cr 1+ goto` then 2drop ;

: b to baddr ;
: s 6 * to selected ;

: p .rows ;


