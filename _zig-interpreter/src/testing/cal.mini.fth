2025 value year
: leap? year 4 mod 0= year 100 mod and year 400 mod 0= or ;
\ jan 1st 1968 was a monday
: jan1dow year 1968 - dup 365 7 */mod nip swap 3 + 4 / + ;

: days d" \x1f\x1c\x1f\x1e\x1f\x1e\x1f\x1f\x1e\x1f\x1e\x1f" ;
: +day 1 = leap? and if 1+ then ;
: #days dup days + c@ swap +day ;

: dows d" \x00\x03\x03\x06\x01\x04\x06\x02\x05\x00\x03\x05" ;
: +dow 1 > leap? and if 1+ then ;
: month1dow dup dows + c@ swap +dow jan1dow + 7 mod ;

: .blanks 0 |: 2dup > if 3 spaces 1+ loop then 2drop ;

( days currday dow -- )
: ?cr over + 7 mod flip = or 0= if cr then ;
( month dow -- )
: .days >r #days 1 |: 2dup >= if dup 2 u.r space 2dup r@ ?cr 1+
  loop then r> 3drop ;

: .dows ." m  t  w  t  f  s  s" ;
: .name 3 d" janfebmaraprmayjunjulaugsepoctnovdec" [] type ;
: .month dup dup .name cr .dows cr
  month1dow dup .blanks .days cr ;

: 1cal 1- .month ;
: 3cal 1- 3 range |: 2dup > if dup 12 mod .month 1+
  loop then 2drop ;
: 12cal to year 12 0 |: 2dup > if dup if cr then dup .month 1+
  loop then 2drop ;
