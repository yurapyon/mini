\ write to external addr
\ read might not be needed

\ any avr words are automatically in compile mode
\ so you mostly write macro-assm code to be interpreted by forth

variable ram
0 ram !
: var   ram @ constant ram +! ;
: byte  1 var ;
: short 2 var ;

\ progmem
variable pm
0 pm !
: pm@ ;
: pm! 2drop ;
: pm, pm pm! 1 pm +! ;

\ eeprom
variable ee
0 ee !
: ee@ ;
: ee! 2drop ;
: ee, drop ;

: avr-call 0 ;
: avr-goto 0 ;

: label pm @ constant ;

variable lastfn

: fn
  pm @
  dup lastfn !
  create ,
  does> avr-call pm, @ pm, ;

: golast avr-goto pm, lastfn @ pm, ;

: addr pm ! ;

: nop, 0 pm, ;

\ memory layout

short %here
short %latest

\ program

start-write

0x0000 addr
label resets

0x0080 addr
label init

fn return

fn function
  golast

fn something
  nop,,
  nop,,
  nop,,
  function

end-write
