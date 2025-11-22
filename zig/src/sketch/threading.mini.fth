make frame
  \ ." wowo" cr
  ;

pdefault
hex
00 00 00 0 pal!
ff ff ff 1 pal!
00 00 ff 2 pal!
00 ff 00 3 pal!
ff 00 00 4 pal!
00 ff ff 5 pal!
ff ff 00 6 pal!
ff 00 ff 7 pal!
40 40 40 8 pal!
40 40 a0 9 pal!
40 a0 40 a pal!
a0 40 40 b pal!
40 a0 a0 c pal!
a0 a0 40 d pal!
a0 40 a0 e pal!
a0 a0 a0 f pal!
decimal

0 variable last-color

make on-key
  nip 1 = if
    0 0 640 400 last-color @ putrect
    last-color @ 1 + 16 mod last-color !
  then
  ;

main
