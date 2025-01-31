2025 value year
: leap? year 4 mod 0= ;
\ jan 1st 1996 was a monday
: dowy year 1996 - dup 365 * swap 3 + 4 / + ;

: days d" \x1f\x1c\x1f\x1e\x1f\x1e\x1f\x1f\x1e\x1f\x1e\x1f" ;
: +day 1 = leap? and if 1+ then ;
: #days dup days + c@ swap +day ;

: dows d" \x00\x03\x03\x06\x01\x04\x06\x02\x05\x00\x03\x05" ;
: +dow 1 > leap? and if 1+ then ;
: dowm dup dows + c@ swap +dow ;

: monthstart dowm dowy + 7 mod ;

: ?cr ( days currday dow -- )
  over + 7 mod -rot = or 0= if cr then ;

: .dows ." m  t  w  t  f  s  s" ;
: month 3 d" janfebmaraprmayjunjulaugsepoctnovdec" [] ;
: .month dup month type cr .dows cr
  dup monthstart >r
     r@ 0 ` 2dup > if space space space 1+ loop` then 2drop
  #days 1 ` 2dup >= if dup 2 u.r space 2dup r@ ?cr 1+
  loop` then 2drop
  r> drop cr ;

: 1cal 1- .month ;
: 3cal 1- 3 range ` 2dup > if dup 12 mod .month 1+
  loop` then 2drop ;
: 12cal to year 12 0 ` 2dup > if dup if cr then dup .month 1+
  loop` then 2drop ;
