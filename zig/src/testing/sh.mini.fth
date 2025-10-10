vocabulary asdf
asdf definitions
current @ @ . cr
s" here" find .s cr
: wow wow ;
current @ @ . cr
' wow .s cr





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
