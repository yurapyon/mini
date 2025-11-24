\ interpreter ext

: skip dup current @ @ = if @ then ;

0 variable #order
create contexts 16 cells allot

: (find) ( name len skip? -- addr ) >r #order @ |: dup 0 u> if
    3dup 1- cells contexts + @ @ r@ if skip then locate ?dup 0= if 1- loop then
  else 0 then r> drop >r 3drop r> ;

: interpret word! ?dup if
    state @ if
      2dup cvocab @ skip locate ?dup if -rot 2drop >cfa execute else
      2dup true (find) ?dup          if -rot 2drop >cfa , else
      2dup >number                   if -rot 2drop lit, , else
        drop 0 state ! align wnf @ execute
      then then then
    else
      2dup false (find) ?dup if -rot 2drop >cfa execute else
      2dup >number           if -rot 2drop              else
        drop wnf @ execute
      then then
    then
    stay @ if loop then
  else
    drop
  then ;

: find ( name len -- addr ) false (find) ;

\ search order ===

: context contexts #order @ ?dup if 1- cells + else abort then ;

: forth       fvocab context ! ;    \ ( -- )
: compiler    cvocab context ! ;    \ ( -- )
: definitions context @ current ! ; \ ( -- )

: push-order 1 #order +! context ! ;

: set-order 0 #order ! >r |: r@ if
    push-order r> 1- >r
  loop then r> drop ;

: also context @ push-order ;
: previous -1 #order +! ;

: vocabulary create 0 , does> context ! ;
: >vocab     2 cells + ;

: words ( -- )   context @ @ check!0 if dup .word @ loop then drop ;

fvocab 1 set-order

vocabulary root
here cell - . cr

also root definitions
: forth forth ;
previous definitions

: only ['] root >vocab dup 2 set-order ;

\ ===

only forth

interpret

vocabulary asdf
here cell - . cr

only forth
also asdf definitions
: wawa 10 15 + . ;
: wawa wawa ." 2" cr ;

wawa

only forth
wawa

interpret

also asdf

wawa
