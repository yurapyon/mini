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

: begin
  here @
  ; immediate

: until
  ['] branch0 c,
  here @ - c, ; immediate

: loop
  0
  begin
    ##.s
    1+
    dup 10 =
  until
  drop
  ;


loop


bye
