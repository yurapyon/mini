word : define
' word nip c, ' define nip c,
' ] nip c,
' exit nip c,

word immediate define
' latest nip ##absjump ' @ nip c,
' 2 nip c, ' + nip c,
' dup nip c,
' c@ nip c, ' lit nip c, 0b10000000 ,
' or nip c,
' swap nip c, ' c! nip c,
' exit nip c,

word ; define
' litc nip c, ' exit nip c, ' c, nip c,
' [ nip c,
' exit nip c,

immediate

: here2 here ;

here here2 ##.s

bye
