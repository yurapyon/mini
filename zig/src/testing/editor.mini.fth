: test-str s" asdf\nqwerty\nzxc\n\0" ;

( x y x y -- ordering )
: direction [by2] compare dup if swap then drop ;

: -trailing dup if 2dup + 1- c@ bl = if 1- loop then then ;

( addr len -- len )
: line-len -trailing nip ;

\ 1024 constant max-len

( addr -- n t/f )
\ : line-len 0 >r max-len range |: 2dup > if c@+ 10 = 0= if r> 1+ >r loop then 2drop r>
  \ dup max-len = 0=
\ ;

( addr -- addr t/f )
\ : next-line dup line-len if 1+ + true else false then ;

\ : .lines |: dup line-len 2dup type cr ;

( line# addr max -- addr )
\ : line@y
  \ range 0 >r |: 2dup > if c@+ 10 = if r> 1+ >r then loop then 2drop r> drop
  \ ;

quit

( x y lines -- x )
: lines.snapx lines.len@y min ;

( x y dx/y lines -- x/y )
: lines.+x rot swap lines.len@y keepin ;
: lines.+y line-ct keepin nip ;

( x y dy lines -- x y )
: lines.+y-fixx >r >r 2dup r> r@ lines.+y nip
  ( x newy r: lines )
  2dup r> lines.snapx flip drop ;

( desx x -- desx x )
: floatx drop dup ;
: snapx  nip dup ;

( desx x y dx/y lines -- desx x y )
: cursor+x >r >r tuck r> r> lines.+x swap >r snapx r> ;
: cursor+y >r >r >r floatx r> r> r> lines.+y-fixx ;

quit

( addr min max )
\ : dsclamp rot dup >r @ -rot sclamp r> ! ;

\ ===

s[ cell field >p.x cell field >p.y ]s point

: <point> rot swap !+ !+ drop ;
: .point dup >p.y @ swap >p.x @ ." (" u. ." , " u. ." )" ;

: p.>s @+ swap @ ;

: p.compare >r p.>s r> p.>s 2compare ;

\ ===


0 [if]
s[ ]s line-buffer

: lb.len-at-cy 2drop 0 ;
: lb.len       drop  0 ;

\ ( point* lb -- )
: lb.clamp-x over >p.y @ swap lb.len-at-cy
  swap >p.x 0 -rot dsclamp ;
: lb.clamp-y lb.len swap >p.y 0 -rot dsclamp ;
: lb.clamp 2dup lb.clamp-x lb.clamp-y ;
[then]

\ ===

s[
  point field >c.actual
  cell  field >c.dx
]s cursor



( x desx -- x desx )
: floatx nip dup ;
: snapx  drop dup ;

variable desx


( cursor -- )
: c.floatx dup >c.dx swap floatx ;
: c.snapx  dup >c.dx swap snapx ;

( cursor dx/y lines -- )
: cursor+x >r >r dup p.>s r> r> +x-lines over >p.x !
  c.snapx ;
: cursor+y rot dup c.floatx -rot
  >r >r dup p.>s >r r@ +y-fixx rot <point> ;

( cursor -- )
: c.floatx dup >c.dx swap >p.x  cell move ;
: c.snapx  dup >p.x  swap >c.dx cell move ;
( dx/y lines cursor -- )
: c.+x swap >r tuck p.>s rot r> +x-lines over >p.x ! c.snapx ;
: c.+y dup c.floatx swap >r
  tuck p.>s rot r@ +y-lines over >p.y !
  dup p.>s r> snapx-lines swap >p.x ! ;

compiler
\ tuck @ [word] swap !
: [!]  ['] tuck , ['] @ , ' , ['] swap , ['] ! , ;

\  >r r@ @ -rot [word] r> !
: [!2] ['] >r , ['] r@ , ['] @ , ['] -rot , ' , ['] r> , ['] ! , ;
forth


\ ===

s[ point field >s.anchor point field >s.endpoint ]s selection

: s.direction dup >s.anchor swap >s.endpoint p.compare
  dup 0= if drop else nip then ;

\ ===

s[
  cell   field >e.mode
  cursor field >e.cursor
]s editor

0   enum m.normal
    enum m.insert
    enum m.visual
    enum m.visual-line
    enum m.view-only
constant modes-ct

: <editor> editor erase ;
