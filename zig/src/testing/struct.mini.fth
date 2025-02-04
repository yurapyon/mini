0 cell field >a
  cell field >b
  cell field >c
constant thingA

0   cell field >tc
  thingA field >ta
constant thingB

create b thingB allot
: <b> 0 over >tc !
      >ta <a> ;

: b.tc+b.ta.a dup >tc @ over >ta >a ! drop ;

: record 0 ;
: endrecord constant ;

( d min max addr )
: dclamp >r rot r@ @ + -rot clamp r> ! ;

( min max addr )
: dclamp dup >r @ -rot clamp r> ! ;
: dsclamp dup >r @ -rot sclamp r> ! ;

record
  cell field >p.x
  cell field >p.y
endrecord point

: <point>.0 over 0 >p.x ! 0 swap >p.y ! ;

: ls.len ;
: ls.at-cursor >c.actual >p.y + ;
: ls.clamp ls.len 0 swap clamp ;
: l.len >l.str >s.len @ ;
: l.clamp ( x line -- x ) l.len 0 swap clamp ;

record
  cell  field >c.dx
  point field >c.actual
endrecord cursor

: <cursor> 0 over >c.dx ! c.actual <point>.0 ;
: c.set-x 2dup >c.dx ! >c.actual >p.x ! ;
: c.set-y >c.actual >p.y ! ;

\ ( amax cursor -- )
: c.fix-x tuck >c.dx @ min swap >c.actual >p.x ! ;

\ ( lines dx cursor -- )
: c.move-x tuck >c.dx +! tuck ls.at-cursor l.len 0 flip >c.dx dsclamp ;

\ ( lines dy cursor -- )
: c.move-y
  tuck >c.actual >p.y +!
  2dup swap ls.len 0 flip >c.actual >p.y dsclamp
  tuck ls.at-cursor l.len swap c.fix-x ;

\ ===

\ ( x* line -- )
: l.fit-x  l.len  0 flip dsclamp ;
\ ( y* lines -- )
: ls.fit-y ls.len 0 flip dsclamp ;

record
  cell  field >c.dx
  point field >c.actual
endrecord cursor

: <cursor> 0 over >c.dx ! c.actual <point>.0 ;

: c.snap-a dup >c.dx @ swap >c.actual >p.x ! ;

\ ( amax cursor -- )
: c.float-a tuck >c.dx @ min swap >c.actual >p.x ! ;

\ ( lines dx cursor -- )
: c.move-x >r
  r@ >c.dx +!
  r@ ls.at-cursor r@ >c.dx swap l.fit-x
  r> c.snap-a ;

\ ( lines dy cursor -- )
: c.move-y >r
  r@ >c.actual >p.y +!
  r@ >c.actual >p.y over ls.fit-y
  r@ ls.at-cursor l.len r> c.float-a ;

\ ===

( addr min max )
: dsclamp rot dup >r @ -rot sclamp r> ! ;

\ ( point* ls -- )
: ls.clamp-x over >p.y @ swap ls.len-at-cy
  swap >p.x 0 -rot dsclamp ;
: ls.clamp-y ls.len swap >p.y 0 -rot dsclamp ;
: ls.clamp 2dup ls.clamp-x ls.clamp-y ;

record
  cell  field >c.dx
  point field >c.actual
endrecord cursor

: <cursor> 0 over >c.dx ! c.actual <point>.0 ;

\ ( lines dx/y cursor -- )
: c.move-x >r
  r@ >c.actual >p.x +!
  r@ >c.actual swap ls.clamp-x
  r@ >c.actual >p.x r> >c.dx ! ;

: c.move-y >r
  r@ >c.actual >p.y +!
  r@ >c.dx r@ >c.actual >p.x !
  r> >c.actual swap ls.clamp ;

record
  cell   field >e.mode
  cursor field >e.cursor

endrecord editor
