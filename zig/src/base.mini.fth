word >flags define ] 2 + exit [
word xorc! define ] tuck c@ xor swap c! exit [

word immediate define ] 0b10000000 latest @ >flags xorc! exit [
word hide define ] 0b01000000 swap >flags xorc! exit [

word : define ] word define latest @ hide ] exit [
word ; define
' litc c, ] exit c,
latest @ hide [
' [ c,
] exit [
immediate

: 2dup over over ;
: 2drop drop drop ;
: 2over 3 pick 3 pick ;
: 3dup 2 pick 2 pick 2 pick ;
: 3drop drop 2drop ;

1 2 2dup ##.s

bye
