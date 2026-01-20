external _tco
external _no-tco

0 variable errno

compiler definitions
: try lit, 0 , ['] errno , ['] ! ,
      ' ,
      ['] errno , ['] @ , ;
forth definitions

: throw errno ! r> drop ;

: wowo 1 throw 3 .  cr ;

: wawa try wowo if ." wowo fail\n" 2 throw then ;

: x    try wawa if ." wawa fail\n" then ;

_no-tco
errno @ . cr
wowo
errno @ . cr
wawa
errno @ . cr
x
errno @ . cr

bye




0 variable last-exception

external _tco
external _no-tco

compiler definitions
: try ['] _no-tco , ;
: catch
  ['] last-exception , ['] @ ,
  [compile] if
  ['] last-exception , ['] @ ,
  lit, 0 , ['] last-exception , ['] ! , ;
: endcatch [compile] then ['] _tco , ;
forth definitions

: throw last-exception ! r> drop ;

: wowo last-exception @ 1+ throw 3 .  cr ;

: wawa last-exception @ . cr
       wowo
       last-exception @ . cr ;

_no-tco
: x try wowo catch ;

x

bye

try wawa catch . cr endcatch

bye


: wawa try wowo catch throw endcatch ;

try wawa catch . cr endcatch
