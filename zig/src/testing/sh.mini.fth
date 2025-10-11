


: skip-current dup current @ @ = if @ then ;

t: locate |: dup if 3dup name string= 0= if @ loop then then nip nip t;

t: interpret word! ?dup if
    state @ if
      2dup cvocab @    skip-current locate ?dup if -rot 2drop >cfa execute else
      2dup context @ @ skip-current locate ?dup if -rot 2drop >cfa , else
      2dup fvocab @    skip-current locate ?dup if -rot 2drop >cfa , else
      2dup >number if -rot 2drop lit, , else drop
        0 literal state ! align wnf @ execute
      then then then
    else
      2dup context @ @ locate ?dup if -rot 2drop >cfa execute else
      2dup fvocab @    locate ?dup if -rot 2drop >cfa execute else
      2dup >number if -rot 2drop else drop
        wnf @ execute
      then then
    then
    stay @ if loop then
  else
    drop
  then t;

( name len -- addr/0 )
t: find 2dup context @ @ locate ?dup if nip nip else fvocab @ locate then t;

t: ' word find dup if >cfa then t;



bye

vocabulary asdf
asdf definitions
current @ @ . cr
s" here" find .s cr
: wow wow ;
current @ @ . cr
' wow .s cr

forth definitions
: wow 1 . cr ;
wow

: qwer [ asdf ] qwer ;

asdf definitions
: if 1 . ;

forth definitions
: if [ asdf ] if then ;

: wow [ s" wowo" define ] wow ;

s" wowo" define docol# , ' wowo , ' exit ,
s" wowo" define ] wowo [

create thing thing

bye

( name len start -- addr )
: locate dup if context @ current @ = state @ and if @ then then
  |: dup if 3dup name string= 0= if @ loop then then nip nip ;

( name len -- addr )
: find 2dup context @ @ locate ?dup if -rot 2drop else
  fvocab @ locate then ;

( name len -- addr compiler-word? )
: lookup 2dup cvocab @ locate ?dup if -rot 2drop true else
  find false then ;

\ if it doesnt find it, ok
\ if it finds it, and its not most recent, ok
\ if it finds it, and its the most recent, search again

( name len start -- addr )
\ : loc,skip drop current @ @ locate ;

\ todo need to check it isn't 0 before dereferencing it
\ another thing could be that '0 @' is 0

\ : locskip 3dup locate dup current @ @ = if drop @ locate else
   \ >r 3drop r> then ;

\ : locprev state @ if drop current @ @ then locate ;

\ : find 2dup context @ @ locprev ?dup if nip nip else
  \ fvocab @ locprev then ;

\ NOTE todo
\ there is a bug where compiler words are being found and executed
\   while in interpreter mode

( name len -- compiler-word? addr/0 )
\ : lookup
   \ 2dup cvocab @ locprev ?dup if nip nip true swap else
   \ 2dup find ?dup if nip nip false swap else 2drop 0
   \ then then ;

\ : ' word find dup if >cfa then ;
