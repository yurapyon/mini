\ interpreter ext

false variable skip?

: locate |: skip? @ if dup current @ @ = if @ then then dup if
    3dup name string= 0= if @ loop then
  then nip nip ;

0 variable context#
create contexts 16 cells allot

: find ( name len -- addr ) context# @
  |: 3dup cells contexts + @ @ locate dup 0= if
    over if drop 1- loop then
  then >r 3drop r> ;

: interpret word! ?dup if
    state @ if true skip? !
      2dup cvocab @ locate ?dup if -rot 2drop >cfa execute else
      2dup find ?dup            if -rot 2drop >cfa , else
      2dup >number              if -rot 2drop lit, , else
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

\ search order ===

: context contexts context# @ cells + ;

: forth       fvocab context ! ;    \ ( -- )
: compiler    cvocab context ! ;    \ ( -- )
: definitions context @ current ! ; \ ( -- )

: vocabulary create 0 , does> context ! ;

: only 0 context# ! ;
: also context @ 1 context# +! context ! ;
: previous -1 context# +! ;

\ ===

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
