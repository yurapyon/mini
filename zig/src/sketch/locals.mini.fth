create tstack 8 cells allot
here constant t0

( ... ct -- )
: tags cells >r s* @ t0 r@ - r@ move r> s* +! ;
: tag  create 1+ cells t0 swap - , does> @ @ ;
0 tag @0 1 tag @1 2 tag @2 3 tag @3
4 tag @4 5 tag @5 6 tag @6 7 tag @7

\ : 4tags
  \ s* @ [ t0 4 cells - ] literal [ 4 cells ] literal move
  \ 4 cells s* +! ;

\ : itags s* @ lit addr lit len move lit len s* +! ;
\ : thing [tags] 4 ;

: tags, cells >r
  ['] s* , ['] @ , lit, t0 r@ - , lit, r@ , ['] move ,
  lit, r> , ['] s* , ['] +! , ;

\ : thing [ 4 itags ]


( a b c -- c b a )
: flipy [ 3 tags, ] @2 @1 @0 ;

1 2 3 flipy .s cr

0 tag @x0
1 tag @y0
2 tag @x1
3 tag @y1
( x0 y0 x1 y1 -- x y )
: math [ 4 tags, ] @x0 @x1 + @y0 @y1 + ;

1 1 2 5 math .s cr

bye

\ : @0 [ t0    cell - ] literal @ ;
\ : @1 [ t0 2 cells - ] literal @ ;
\ : @2 [ t0 3 cells - ] literal @ ;
\ : @3 [ t0 4 cells - ] literal @ ;
\ : @4 [ t0 5 cells - ] literal @ ;
\ : @5 [ t0 6 cells - ] literal @ ;
\ : @6 [ t0 7 cells - ] literal @ ;
\ : @7 [ t0 8 cells - ] literal @ ;

: tags ( ... ct -- )
  cells >r
  s* @ tstack r@ move r@ s* +!
  tstack r> + cell - t* ! ;

\ locals
\ |header--|docol---|jump----|*-------|l0------|l1------|

\ docol l0 ! l1 ! jump * (l0) (l1) code... l0 @ l1 @

\ docol lclear >l >l code... 0 @l 1 @l

\ : tpad here 128 + ;
\ 0 variable ttop
\ : @t cells tpad + @ ;

\ : tags ( ... ct -- )
  \ >r
  \ tpad r@ 1- cells + ttop !
  \ |: r@ if ttop @ ! ttop @ cell - ttop ! r> 1- >r loop then
  \ r> drop ;

create lstack 8 cells allot
0 variable ltop
: @l cells lstack + @ ;

: tags ( ... ct -- )
  >r
  lstack r@ 1- cells + ltop !
  |: r@ if ltop @ ! ltop @ cell - ltop ! r> 1- >r loop then
  r> drop ;



\ local def
\ |prev|prev|name|char|char|align|docon|value|
\ 6 32 + constant local
\ create lpad 8 local * allot

create ldict 1024 allot
0 variable lh
: lhere  lh @ ;
: lalign lhere aligned lh ! ;
: l,     lhere ! lh cell +! ;
: lc,    lhere c! lh 1 +! ;
: lallot lh +! ;

0 variable llast

vocabulary locals
: ldefine
  lalign lhere >r [ ' locals >value ] @ l,
  dup lc, tuck lhere swap move lallot
  lalign r> [ ' locals >value ] ! ;

: lnew
  ldefine docol @ l,

  ['] , l,
  \ ldefine docol @ l, ['] lit l, llast @ l, [']
  \ llast 1 +! ;

: lreset
  0 llast ! 0 lh ! ;
