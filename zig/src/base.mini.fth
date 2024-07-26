word >flags define
' 2 c, ' + c,
' exit c,

word xorc! define
' tuck c, ' c@ c, ' xor c, ' swap c, ' c! c,
' exit c,

word immediate define
' litc c, 0b10000000 c,
' latest ##absjump ' @ c, ' >flags ##absjump
' xorc! ##absjump
' exit c,

word hide define
' litc c, 0b01000000 c,
' swap c,
' >flags ##absjump
' xorc! ##absjump
' exit c,

word : define
' word c, ' define c,
' latest ##absjump ' @ c, ' hide ##absjump
' ] c,
' exit c,

word ; define
' litc c, ' exit c, ' c, c,
' latest ##absjump ' @ c, ' hide ##absjump
' [ c,
' exit c,

immediate

: begin
  here @
  ; immediate

: until
  ['] branch0 c,
  here @ - c, ; immediate

: \
  begin
    next-char 10 =
  until ; immediate

\ does this work

: 2dup over over ;
: 2drop drop drop ;
: 2over 3 pick 3 pick ;
: 3dup 2 pick 2 pick 2 pick ;
: 3drop drop 2drop ;

1 2 2dup ##.s

bye
