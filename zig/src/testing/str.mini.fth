struct A {
  cell this
  cell that
}

a.this

struct B {
  A thing1
  A thing2
}

B.thing1.this

ns A {
  0 cell field this
    cell field that
  constant size
}

ns B {
  0 A size field thing1
    A size field thing2
  constant size
}

B thing1 this




: bi word find word find swap execute execute ;

1 2 bi 1+ 1-

0
cell field >a
cell field >b
constant t0

0 cell field >c
  cell field >d
constant t1

*t0 *t1 bi >a >c + ;

*t0 *t1 >c swap >a +
*t0 *t1 >r >a r> >c +

