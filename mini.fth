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

32 k       constant mmem-sz
128 `cells constant mstk-sz
128 `cells constant mrstk-sz
128        constant mibuf-sz

0    `cell memmap mpc
    buffer memmap mibuf
  mibuf-sz memmap mibuf-mem
    buffer memmap mstk
   mstk-sz memmap mstk-mem
    buffer memmap mrstk
  mrstk-sz memmap mrstk-mem
     `cell memmap mhere
     `cell memmap mlatest
     `cell memmap mstate
constant mdict-start

create mmem mmem-sz allot
: >m mmem + ;
: m! >m `! ;
: m@ >m `@ ;
: |pc| mpc  >m ;
: |i| mibuf >m ;
: |s| mstk  >m ;
: |r| mrstk >m ;

: init-vm
  0 mpc m!
  mibuf-sz |i| <buffer>
  mstk-sz  |s| <buffer>
  mrstk-sz |r| <buffer>
  mdict-start mhere m!
  0 mlatest m!
  0 mstate m! ;

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

: .mmem-status
  ."    mdict start: " mdict-start . cr
  ." builtins count: " builtins-ct . cr
  ;

\ ===

.mmem-status

