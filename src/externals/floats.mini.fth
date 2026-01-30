external f+
external f-
external f*
external f/
external f>str
external str>f

: fswap 2swap ;
: fdrop 2drop ;
: fdup  2dup ;

create fbuf 128 allot
: f. fbuf 128 f>str fbuf swap type ;

: F word str>f drop ;
also compiler definitions
: F word str>f drop swap lit, , lit, , ;
previous definitions

\ : f, swap , , ;
\ : f@ @+ swap @ ;
\ : fconstant create f, does> f@ ;

\ todo this is messy
: u>f <# #s #> str>f drop ;

