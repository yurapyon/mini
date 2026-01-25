\ ===
\
\ calendar
\
\ > 2020 12cal
\
\ jan ================
\ m  t  w  t  f  s  s
\        1  2  3  4  5
\  6  7  8  9 10 11 12
\ 13 14 15 16 17 18 19
\ 20 21 22 23 24 25 26
\ 27 28 29 30 31
\
\ feb ================
\ m  t  w  t  f  s  s
\                 1  2
\  3  4  5  6  7  8  9
\ 10 11 12 13 14 15 16
\ 17 18 19 20 21 22 23
\ 24 25 26 27 28 29
\
\ mar ================
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

: %by mod 0= ;

: leapyear? ( yr -- b ) dup 4 %by over 100 %by 0= and swap 400 %by or ;
: leapyears ( yr -- n ) dup 4 / over 100 / - swap 400 / + ;
: jan1st    ( yr -- n ) 1600 - dup 365 7 */mod nip swap 1- leapyears + 6 + ;

: days/mo ( mo yr -- days ) over 1 = over leapyear? and 1 and nip
  swap d" \x1f\x1c\x1f\x1e\x1f\x1e\x1f\x1f\x1e\x1f\x1e\x1f" + c@ + ;

: 1st/mo  ( mo yr -- 1st )  over 1 > over leapyear? and 1 and swap jan1st +
  swap d" \x00\x03\x03\x06\x01\x04\x06\x02\x05\x00\x03\x05" + c@ + 7 mod ;

: .line ( end start ) |: 2dup > if
  dup dup 0 > if 2 u.r else drop 2 spaces then space
  1+ loop then 2drop ;

: .days ( mo yr -- ) 2dup days/mo 1+ -rot 1st/mo 1 swap -
  |: 2dup > if 2dup 7 + min over .line cr 7 + loop then 2drop ;

: .header ( mo -- ) 3 d" janfebmaraprmayjunjulaugsepoctnovdec" [] type
  ."  ================" cr ." m  t  w  t  f  s  s" cr ;

: 1cal  ( mo yr -- ) swap 1- swap over .header .days ;
: 12cal ( year -- )  >r 12 0 check> if
    dup .header dup r@ .days cr
  1+ loop then r> 3drop ;
