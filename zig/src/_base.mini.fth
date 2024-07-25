word : define
' word nip c, ' define nip c,
' ] nip c,
' exit nip c,

word ; define
' lit nip c, ' exit nip c, ' , nip c,
' [ nip c,
' exit nip c,

\ latest @ make-immediate
\ 4 dup 1+ dup 1+ ##.s bye
