vocabulary avr
avr definitions

\ todo just use pad for now but think about allocating a
\   separate avr pad

\ incremented on write
variable avr-here

variable pad-here

: avr: avr pad pad-here ! ;
: ;avr forth pad 64 dump ;
: avr, pad-here @ ! cell pad-here +! ;

: nop  0 avr, ;
: add  1 avr, ;
: addc 2 avr, ;

: label avr-here constant ;

: fn: avr: label ;

avr:
  nop
  1 2 add
  1 2 addc

  (later),


  \ jump-abs!

label loop

  ;avr

fn: name
  ;avr

forth definitions
avr


forth
