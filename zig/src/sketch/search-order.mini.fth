\ interpreter ext

: skip? dup current @ @ = if @ then ;

0 variable context#
create contexts 16 cells allot

: (find) ( name len skip? -- addr ) >r context# @
  |: 3dup cells contexts + @ @ r@ if skip? then locate dup 0= if
    over if drop 1- loop then
  then r> drop >r 3drop r> ;

: interpret word! ?dup if
    state @ if
      2dup cvocab @ skip? locate ?dup if -rot 2drop >cfa execute else
      2dup true (find) ?dup           if -rot 2drop >cfa , else
      2dup >number                    if -rot 2drop lit, , else
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

\ search order ===

: find ( name len -- addr ) false (find) ;

: context contexts context# @ cells + ;

: forth       fvocab context ! ;    \ ( -- )
: compiler    cvocab context ! ;    \ ( -- )
: definitions context @ current ! ; \ ( -- )

: only 0 context# ! ;
: also context @ 1 context# +! context ! ;
: previous -1 context# +! ;

: vocabulary create 0 , does> context ! ;

: words ( -- )   context @ @ check!0 if dup .word @ loop then drop ;

\ ===

only forth
interpret

here . cr
: hi ." hi" cr ;
: wa ." wa" cr ;

vocabulary test
also test definitions

here . cr
: hello ." hello" cr ;
: wawa ." wawa" cr ;

previous definitions

vocabulary test2
also test2 definitions

here . cr
: hello2 ." hello2" cr ;
: wawa2 ." wawa2" cr ;

previous definitions

only forth also test also test2

\ forth words

hi
wa
hello
wawa
hello2
wawa2
wahaha

only forth interpret

only forth
also test2 definitions

: def ." def" ;
: def def ." d2" def cr ;

only forth
also test2

def

bye





: >> word find ?dup if >cfa execute else ." not found" cr then ;

here . cr
: hi ." hi" cr ;
: wa ." wa" cr ;

vocabulary test
test definitions

here . cr
: hello ." hello" cr ;
: wawa ." wawa" cr ;

forth definitions

vocabulary test2
test2 definitions

here . cr
: hello2 ." hello2" cr ;
: wawa2 ." wawa2" cr ;

forth definitions

only forth also test also test2

contexts 16 cells dump

.s cr
>> hi
>> wa
>> hello
>> hello2
>> wawa
>> wawa2
>> xxx
.s cr

: def ;
true skip? !
>> def
.s cr
