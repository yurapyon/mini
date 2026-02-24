0 [if]
vocabulary symbols

0 variable #sym
: defsym
  also symbols definitions
  define ['] docon @ , #sym @ ,
  1 #sym +!
  previous definitions
  ;

: intern 2dup also symbols find previous ?dup
  if nip nip >cfa cell + @ else #sym @ -rot defsym then ;

: ` word intern ;
also compiler definitions
: [`] word intern lit, , ;
previous definitions
[then]

also compiler definitions
: [`]
  ['] jump , (later), word intern this!
  lit, , ;
previous definitions

.s cr 
: wawa [`] xxx . cr ;
.s cr 

: counter  ht.new dup [`] ct 0 flip ht! ;
\ : ct.inc   [`] ct swap 2dup ht@ 1+ -rot ht! ;
\ : ct.count [`] ct swap ht@ ;

\ counter constant (ct)
\ (ct) ct.inc
\ (ct) ct.inc
\ (ct) ct.inc
\ (ct) ct.count . cr

0 [if]

: set   ` true flip ht! ;
: clear ` false flip ht! ;
: has   ` swap ht.has? ;

ht.new constant (ht)
(ht) set wawa
(ht) set wawa2

(ht) has wawa . cr
(ht) has wawa2 . cr
(ht) has haha . cr
[then]
