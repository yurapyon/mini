\ ===
\
\ calendar
\
\ > 2020 12cal
\
\ jan
\ m  t  w  t  f  s  s
\        1  2  3  4  5
\  6  7  8  9 10 11 12
\ 13 14 15 16 17 18 19
\ 20 21 22 23 24 25 26
\ 27 28 29 30 31
\
\ feb
\ m  t  w  t  f  s  s
\                 1  2
\  3  4  5  6  7  8  9
\ 10 11 12 13 14 15 16
\ 17 18 19 20 21 22 23
\ 24 25 26 27 28 29
\
\ mar
\ m  t  w  t  f  s  s
\                    1
\  2  3  4  5  6  7  8
\  9 10 11 12 13 14 15
\ 16 17 18 19 20 21 22
\ 23 24 25 26 27 28 29
\ 30 31
\
\ ...
\
\ ===

2025 value year

: leap? year 4 mod 0= year 100 mod and year 400 mod 0= or ;

\ jan 1st 1968 was a monday
: jan1-dow year 1968 - dup 365 7 */mod nip swap 3 + 4 / + ;

: days/mo dup d" \x1f\x1c\x1f\x1e\x1f\x1e\x1f\x1f\x1e\x1f\x1e\x1f" + c@
  swap 1 = leap? and if 1+ then ;

: month-dow dup d" \x00\x03\x03\x06\x01\x04\x06\x02\x05\x00\x03\x05" + c@
  swap 1 > leap? and if 1+ then
  jan1-dow + 7 mod ;

: blanks. 0 |: 2dup > if 3 spaces 1+ loop then 2drop ;

( days currday dow -- )
: ?cr over + 7 mod flip = or 0= if cr then ;

( month dow -- )
: days. >r days/mo 1 |: 2dup >= if dup 2 u.r space 2dup r@ ?cr 1+
  loop then r> 3drop ;

: month.
  dup 3 d" janfebmaraprmayjunjulaugsepoctnovdec" [] type cr
  dup ." m  t  w  t  f  s  s" cr
  month-dow dup blanks. days. cr ;

\ ===

( month -- )
: 1cal 1- month. ;

( starting-month -- )
: 3cal 1- 3 range |: 2dup > if dup 12 mod month. 1+
  loop then 2drop ;

( year -- )
: 12cal to year 12 0 |: 2dup > if dup if cr then dup month. 1+
  loop then 2drop ;
