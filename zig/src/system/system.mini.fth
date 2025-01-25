: run mark open-file interpret reset ;


create current-file 2048 allot

: ekey ;

: eloop key ekey recurse ;

eloop

