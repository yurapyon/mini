0   enum %null
    enum %list
constant %number

: <val> 3 cells allocate ;
: type@ 0 swap dyn@ ;
: type! 0 swap dyn! ;
: car   cell swap dyn@ ;
: car!  cell swap dyn! ;
: cdr   2 cells swap dyn@ ;
: cdr!  2 cells swap dyn! ;
: num   car ;
: num!  car! ;

: make-val <val> >r r@ type! r@ car! r@ cdr! r> ;

0 0 %null make-val constant '()
: cons %list make-val ;
: N    0 swap %number make-val ;

: print
  cond
    dup type@ %null   = if drop ." '()" else
    dup type@ %list   = if ." (" dup car [ ' print , ] ." . " cdr [ ' print , ] ." )" else
    dup type@ %number = if num . else
      drop
  endcond ;

'() 1 N cons 2 N cons 3 N cons constant l

l print cr

.s cr
