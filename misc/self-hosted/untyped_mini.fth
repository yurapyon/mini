\ untyped
\ this is messy and incomplete

: k 1024 * ;

: memmap
  over + swap
  create ,
  does> @ ;

: c!+ ( value addr -- addr+1 ) tuck c! 1+ ;
: c@+ ( addr -- value addr+1 ) dup c@ swap 1+ ;

\ ===

: `cell 2 ;
: `cells `cell * ;
: `split   ( `cell -- Lbyte Hbyte ) dup 8 rshift ;
: `combine ( Lbyte Hbyte -- `cell ) 8 lshift or ;
: `! swap `split flip c!+ c! ;
: `@ c@+ c@ `combine ;
: `+! tuck `@ + swap `! ;

\ ===

0 `cell +field >buf-at
  `cell +field >buf-sz
  dup constant >buf-mem
constant buffer

: <buffer> >r
    r@ >buf-sz `!
  0 r> >buf-at `! ;

: >b[] ( idx buf item-sz -- buf[idx] )
  rot * swap >buf-mem + ;

: >b[at] ( buf item-sz -- buf[at] )
  over >buf-at @ -rot >b[] ;

: adv-buf >buf-at `+! ;

: bpush ( value buf -- )
  tuck
  `cell >b[at] `!
  1 swap adv-buf ;

: bpop ( buf -- value )
  dup -1 swap adv-buf
  `cell >b[at] ;

\ : bdrop bpop drop ;
\ : bdup dup bpop swap 2dup spush spush ;

\ ===

0 `cell +field >screen-on-frame
  `cell +field >screen-x
  `cell +field >screen-y
      1 +field >screen-pixel
      1 +field >screen-config \ i.e. refresh rate
constant #screen

0 `cell +field >sprites-x
  `cell +field >sprites-y
  `cell +field >sprites-sprite
constant #sprites

0 1 +field >sys-ptr
  1 +field >sys-len
  1 +field >sys-exit
     `cell aligned-to
constant #system

0     1 +field >console-control
         `cell aligned-to
  `cell +field >console-on-input
      1 +field >console-read
      1 +field >console-write
constant #console

0 `cell +field >source-control
  `cell +field >source-ptr
  `cell +field >source-len
constant #source

0 `cell +field >memcmp-control
  `cell +field >memcmp-src
  `cell +field >memcmp-dest
constant #memcmp

1   flag ^screen
    flag ^sprites
    flag ^system
    flag ^console
    flag ^source
drop

`cell constant dev-connected
`cell constant dev-on

\ mcontrol: compile state, base

\ ===

     64 k constant mmem-sz
32 `cells constant mstk-sz
32 `cells constant mrstk-sz

0       `cell memmap mcontrol
        `cell memmap mpc
        `cell memmap mhere
        `cell memmap mlatest
       buffer memmap mstk
      mstk-sz memmap mstk-mem
       buffer memmap mrstk
     mrstk-sz memmap mrstk-mem

dev-connected memmap mdconn
       dev-on memmap mdon
      #system memmap mdsys
      #source memmap mdsource
constant mdict-start

\ state can have an asm mode
\ 0   enum %interpret
\     enum %compile
\ constant %asm

create mmem mmem-sz allot
: >m mmem + ;
: m! >m `! ;
: m@ >m `@ ;
: |pc| mpc  >m ;
\ : |i| mibuf >m ;
: |s| mstk  >m ;
: |r| mrstk >m ;

: init-vm
  0 mpc m!
  mdict-start mhere m!
  0 mlatest m!
  \ 0 mstate m!
  \ 10 mbase m!
  \ mibuf-sz |i| <buffer>
  mstk-sz  |s| <buffer>
  mrstk-sz |r| <buffer> ;

create builtins 128 cells allot
0 value builtins-ct

: builtin
  builtins builtins-ct cells + ,
  builtins-ct constant
  1 +to builtins-ct ;

:noname ;
builtin `nop

:noname
  \ |pc| `cell + @ |s| spush
  \ |pc| `cell |pc| +! ;
  ;
builtin `lit

\ :noname |s| sdrop ;
0
builtin `drop

\ :noname |s| sdup ;
0
builtin `dup

\ ===

: main-loop
  \ read from stdin
  \ evaluate
  tailcall recurse ;

\ ===

  0 enum `exit
    enum `jump
    enum `branch
    enum `branch0

    enum `find

    enum `lit  \ literal cell
    \ enum `litc \ literal char
    enum `data \ like lit-string, data with length
    enum `'
    enum `[']
    enum `]
    enum `[

    enum `dup
    enum `drop
    enum `swap
    enum `c!
    enum `c@
    enum `c,

    enum `d>
    enum `>d

    enum `+
    enum `-
    enum `*
    enum `u/mod
    enum `lshift
    enum `rshift
    enum `nand

    enum `=
    enum `<

    enum `>r
    enum `r>

    enum `execute
constant bytecode-ct

: .addr ."   0x" 4 u.0 ." : " ;

: .mmem-status
  ." memory layout:  " cr
  hex
  mpc         .addr ." program counter" cr
  mhere       .addr ." here" cr
  mlatest     .addr ." latest" cr
  \ mstate      .addr ." state" cr
  \ mbase       .addr ." base" cr
  \ mibuf       .addr ." input buffer" cr
  \ mibuf-mem   .addr ." input buffer memory" cr
  mstk        .addr ." stack" cr
  mstk-mem    .addr ." stack memory" cr
  mrstk       .addr ." return stack" cr
  mrstk-mem   .addr ." return stack memory" cr
  mdict-start .addr ." dictionary start" cr
  decimal
  ." builtins count: " builtins-ct . cr
  ." bytecode count: " bytecode-ct . cr
  ;

\ ===

.mmem-status

