( ... ct -- xt )
: yield ;

( cxt -- ... )
: resume ;

\ saves 2 cells as stack frame
\ returns a 'closure'
2 yield
