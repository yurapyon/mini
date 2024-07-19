: k 1024 * ;

create `mem 64 k allot
0 value `here

: `cell 2 ;

  0 enum `nop
    enum `lit
    enum `bye
    enum `dup
    enum `swap
    enum `define
    \ bytes
    enum `b!
    enum `b@
    \ words
    enum `w!
    enum `w@
    enum `char
constant bytecode-ct

\ 012301234567
\     builtin-
\ mini

\ 0000111101234567
\ m                miniword
\ b                bytecode

\ bytecode 0-------0-------
\ miniword 1-------01234567
