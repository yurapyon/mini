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

: a .r ;
: aa a ;
: aaa aa ;

_tco
_0ec! aaa _ec@
cr
." tco: " . cr

_no-tco
_0ec! aaa _ec@
cr
." no tco: " . cr

_tco
_0ec!
: qwer .s cr ;
_ec@
cr
." tco: " . cr

_no-tco
_0ec!
: qwer .s cr ;
_ec@
cr
." no tco: " . cr

_tco
_0ec! 0 128 dump _ec@
." tco: " . cr

_no-tco
_0ec! 0 128 dump _ec@
." no tco: " . cr

\ : b .r noop ;
\ : bb b noop ;
\ : bbb bb noop ;

\ _0ec! bbb _ec@
\ cr
\ ." b: " . cr
