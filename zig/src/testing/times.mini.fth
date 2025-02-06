compiler
: fdo [compile] |: ['] 2dup , ['] > , [compile] if ;
: floop ['] + , [compile] loop [compile] then ;
forth

: times swap >r >r |: r> r> dup if 1- >r >r r@ execute loop then 2drop ;

: fill   -rot [: 2dup c!+ nip ;] times 2drop ;
: fill16 -rot [: 2dup  !+ nip ;] times 2drop ;

: spaces ['] space times ;
: type [: c@+ emit ;] times drop ;

: .print [: c@+ print ;] times drop ;
: .bytes [: c@+ h8. space ;] times drop ;
: .line+ over h16. space 2dup .bytes 2dup .print cr + ;
: dump 16 / [: dup 16 .line+ ;] times drop ;

[defined] block [if]
: .line 1- 64 * + 64 .print ;
: .list 0 16 [: dup 2 u.r space 2dup .line cr 1+ ;] times 2drop ;
: list block .list ;
[then]

: bi >r over >r execute r> r> execute ;
