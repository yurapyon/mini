external ht.new
external ht.delete
external ht!
external ht@
external ht.has?

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
