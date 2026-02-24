: wait1 [ 1 beats ] ;

: thing [ 4 beats ]
  asdf
  wait1
  wawa
  wait1
  ;

>> 2 thing
  0 asdf
  wawa ;

frame-ct , * ,
frame-ct , * ,

: track
  2 beats [: note-on c4 ;] q
  2 beats [: note-on e4 ;] q
  2 beats [: note-on g4 ;] q
  ;

0 variable frame-ct
: track 0 frame-ct !
  create here 0 , ;

: beats
  16 * frame-ct +! ;

track asdf



: xyz
  3 _c note,
  2 beats wait,
  2 beats wait,
  ;


\ scheduler
\ threads




( ... ct -- xt )
: yield ;

( cxt -- ... )
: resume ;

\ saves 2 cells as stack frame
\ returns a 'closure'
2 yield
