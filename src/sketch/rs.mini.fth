: t .r noop ;
: tt t noop ;
: ttt tt noop ;

.r cr
t cr
tt cr
ttt cr

: x s" t cr tt cr ttt cr" evaluate ;

s" x" evaluate

doer asdf

: thingy
  |:
    make asdf ." hello\n"
    make asdf ." world\n"
  loop ;

thingy
asdf
asdf
asdf
asdf
asdf
asdf

external _tco
external _no-tco
external _0ec!
external _ec@

: tco[    _tco _0ec! ;
: no-tco[ _no-tco _0ec! ;
: ]tco    _ec@ 288 - ." tco: " . cr ;
: ]no-tco _ec@ 296 - ." no tco: " . cr ;

tco[ ]tco
no-tco[ ]no-tco

: a .r ;
: aa a ;
: aaa aa ;
: aaaa aaa ;
: aaaaa aaaa ;
: aaaaaa aaaaa ;

tco[ aaaaaa ]tco
no-tco[ aaaaaa ]no-tco

vocabulary voc0
voc0 definitions
tco[ : qwer .s cr ; ]tco

vocabulary voc1
voc1 definitions
no-tco[ : qwer .s cr ; ]no-tco

' noop
tco[ execute ]tco
' noop
no-tco[ execute ]no-tco

0 64 ' dump
tco[ execute ]tco
0 64 ' dump
no-tco[ execute ]no-tco

\ : b .r noop ;
\ : bb b noop ;
\ : bbb bb noop ;

\ _0ec! bbb _ec@
\ cr
\ ." b: " . cr
