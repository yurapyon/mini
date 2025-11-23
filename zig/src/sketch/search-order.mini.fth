0 variable context#
create contexts 16 cells allot
: context contexts context# @ cells + ;

: vocabulary create 0 , does> context ! ;

: only 0 context# ! ;
: also context @ 1 context# +! context ! ;
: previous -1 context# +! ;

false variable skip?
: locskip skip? @ if @ @ dup current @ @ = if @ then then locate ;

: find ( name len -- addr ) context# @
  |: 3dup cells contexts + locskip dup 0= if
    over if drop 1- loop then
  then >r 3drop r> ;

: forth       fvocab context ! ;    \ ( -- )
: compiler    cvocab context ! ;    \ ( -- )
: definitions context @ current ! ; \ ( -- )

: interpret word! ?dup if
    state @ if true skip? !
      2dup cvocab @ locskip ?dup if -rot 2drop >cfa execute else
      2dup find ?dup             if -rot 2drop >cfa , else
      2dup >number               if -rot 2drop lit, , else
        drop 0 state ! align wnf @ execute
      then then then
    else false skip? !
      2dup find ?dup if -rot 2drop >cfa execute else
      2dup >number   if -rot 2drop              else
        drop wnf @ execute
      then then
    then
    stay @ if loop then
  else
    drop
  then ;

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

interpret

hi
wa
hello
wawa
hello2
wawa2
xxx

: def ." def" ;
: def def ." d2" def cr ;

def


0 [if]
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
[then]

