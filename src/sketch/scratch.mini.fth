0 variable scratch
: #  <array> scratch ! ;
: #! scratch @ #.>ptr dyn! ;
: #@ ;
: #, ;

#: name asdf qwer #;



scratch
  temp array list, that everything gets compiled into
  can detach the memory and assign it to a definition
#

#.>ptr
#.>h
#.>capacity

s!
s@
s,

sc!
sc@
sc,





#] 32 126 in[,] [ :
printable

scratch
  lit, 32 ,
  lit, 126 ,
  ' in[,] ,
  ' exit ,
word printable define docol , ,

:
word printable define docol , here , scratch ]

;
[ #.>ptr swap !

: printable
  32 126 in[,]
  ;


def
  32 126 in[,]
is printable


