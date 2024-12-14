1 2 +

: print type cr ;

:noname ?dup if 1 . 1- recurse then ;
: thingy 16 [ , ] ;

quit

s" hello" print
