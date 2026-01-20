256 allocate constant mem

\ store and fetch ===

: .mem
  ." size: " mem dynsize . cr

  ." dec: "
  0 mem dyn@ .
  2 mem dyn@ .
  4 mem dyn@ .
  6 mem dyn@ . cr

  ." hex: "
  hex
  0 mem dyn@ .
  2 mem dyn@ .
  4 mem dyn@ .
  6 mem dyn@ . cr

  ." chars: "
  4 mem dync@ .
  5 mem dync@ .
  6 mem dync@ .
  7 mem dync@ . cr
  decimal
  ;

0 0 mem dyn!
5 2 mem dyn!
$dead 4 mem dyn!
$beef 6 mem dyn!

.mem cr

128 mem reallocate

.mem cr

2 0 mem dyn+!
1 4 mem dyn+c!

.mem cr

\ copying ===

create to-copy $abcd , $1234 ,

to-copy 0 mem 2 cells >dyn

.mem cr

4 mem to-copy 2 cells dyn>

hex
to-copy @+ . @ . cr
decimal

0 allocate constant mem2

mem2 . cr
mem2 dynsize . cr

4 cells mem2 reallocate

$abcd 0 mem2 dyn!

0 mem2 dyn@ .short cr
mem2 dynsize . cr

mem free
mem2 free
