: k 1024 * ;

: memmap
  over + swap
  create ,
  does> @ ;

: `cell 2 ;

256 constant mini-stk-size
256 constant mini-rstk-size

create mini-mem 64 k allot
0 mini-stk-size memmap mini-stk-start
  mini-rstk-size memmap mini-rstk-start
  `cell memmap mstk-top
  `cell memmap mrstk-top
  `cell memmap mhere
  `cell memmap mlatest
  `cell memmap mstate
constant mini-dictionary-start

mini-dictionary-start mhere !
0 mlatest !
0 mstate !

  0 enum `nop

    enum `lit
    enum `exit
    enum `define
    enum `bye

    enum `word

    enum `dup
    enum `drop
    enum `swap
    enum `over
    enum `flip
    enum `rot
    enum `-rot

    enum `c!
    enum `c@
    enum `c,

    enum `!
    enum `@
    enum `,

    enum `char

    enum `+
    enum `-
    enum `*
    enum `/mod

    enum `>r
    enum `r>
    enum `r@

    enum `=
    enum `0=
    enum `<
    enum `<=
    enum `>
    enum `>=

    enum `and
    enum `or
    enum `xor
    \ TODO do we need this if we have 0= ?
    enum `invert
    enum `lshift
    enum `rshift

    enum `move
    enum `mem=

    enum `here
    enum `latest

    enum `state
    enum `]
    enum `[

    enum `define

    enum `jump
    enum `branch
    enum `branch0

    enum `emit

    enum `make-immediate
    enum `make-hidden

    enum `ext
constant bytecode-ct

." bytecode count " bytecode-ct . cr

\ bytecode 0-------*-------
\ miniword 1-------*-------
