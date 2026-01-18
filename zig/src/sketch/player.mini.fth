\ state machine
\ is/was
\ using function ptrs for collision response

create pos 0 , 0 ,
create vel 0 , 0 ,

: x@  @ ;
: y@  cell + @ ;
: x!  ! ;
: y!  cell + ! ;
: x+! +! ;
: y+! cell + +! ;

: p+! ( s d -- ) over x@ over x+! swap y@ swap y+! ;

: p! ;
: psign ;
: ps*   ;

: is/was   create false , false , ;
: >now     ;
: >before  cell + ;
: started  @+ 0= swap @ and ;
: stopped  @+ swap @ 0= and ;
: remember @+ swap ! ;

0 value max-speed
0 value accel
40 value gravity

is/was on-floor
is/was on-ceil
is/was on-wall
is/was coasting
is/was jumping

false value can-jump

doer >floor
doer >ceil
doer >wall

doer forces

defer >default
defer >walk
defer >run
defer >fall
defer >jump
defer >coast

:noname
  true to can-jump
  make >floor               ;and
  make >ceil  0 vel y!      ;and
  make >wall  0 vel x!      ;and
  make forces accel vel x+! ;and
; is >default

:noname
  500 to max-speed
  30 to accel
  >default
; is >walk

:noname
  900 to max-speed
  50 to accel
  >default
; is >run

:noname
  false to can-jump
  make forces gravity vel y+!
; is >fall

:noname
  -1000 vel y!
  >fall
; is >jump

:noname
  make >floor vel y@ negate vel y! ;and
  make >ceil  vel y@ negate vel y! ;and
  make >wall  vel x@ negate vel x! ;and
  \ todo fixed point
  make forces 0.98 vel ps* ;and
  false to can-jump
; is >coast

: process
  on-floor? on-floor >now !
  on-ceil? on-ceil >now !
  on-wall? on-wall >now !
  %coast is-pressed? coasting >now !
  %jump is-pressed can-jump and jumping >now !

  jumping started if >jump then

  coasting started if >coast then
  coasting stopped if >default then

  on-floor started if >floor then
  on-floor stopped if >fall then

  on-ceil started if >ceil then
  on-wall started if >wall then

  forces

  on-floor remember
  on-ceil remember
  on-wall remember
  coasting remember
  jumping remember
  ;
