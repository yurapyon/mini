word ##.s      define ' ext c, 0 c, 0 c, ' exit c,
word flipb!    define ] tuck c@ xor swap c! [ ' exit c,
word flipt!    define ] 0x80 swap rshift swap >terminator flipb! [ ' exit c,
word immediate define ] latest @ 1 flipt! [ ' exit c,
word hide      define ]          2 flipt! [ ' exit c,
word :         define ] word define latest @ hide ] [ ' exit c,
word ;         define ] ['] exit c, latest @ hide [ ' [ c, ' exit c, immediate

: exit, ['] exit c, ;
: br,   ['] branch  c, ;
: ?br,  ['] branch0 c, ;
: jump, ['] tailcall c, ;
: lit,  ['] lit  c, ;
: litc, ['] litc c, ;
: ext,  ['] ext c, ;

: blank,     0 c, 0 c, ;
: blankc,    0 c, ;
: later,     here @ blank, ;
: laterc,    here @ blankc, ;
: something, lit, later, ;
: somewhere, jump, later, ;
: return,    exit, blankc, ;

: c!+ tuck c! 1+ ;

: cell>l cell>bytes swap ;
: cell>b cell>bytes ;
: cell,l cell>b c, c, ;
: cell,b cell>l c, c, ;
: cell!l swap cell>b rot c!+ c! ;
: cell!b swap cell>l rot c!+ c! ;

: mkabsjump  0x8000 or ;
: xt,        mkabsjump cell,b ;
: xt!        swap mkabsjump swap cell!b ;

: this       here @ swap ;
: how-far    this - ;
: this!      this cell!l ;
: jump-mark! this xt! ;
: br-mark!   dup how-far swap c! ;
: back,      how-far negate c, ;

: if   ?br, laterc, ; immediate
: else br,  laterc, swap br-mark! ; immediate
: then br-mark! ; immediate

: begin here @ ; immediate
: until ?br, back, ; immediate
: again br,  back, ; immediate
: while ?br, laterc, ; immediate
: repeat swap br, back, br-mark! ; immediate

: char   word drop c@ ;
: [char] litc, char c, ; immediate

: \ begin next-char 10 = until ; immediate

: is()
  dup [char] ( = if  drop 1 [ exit, ] then
      [char] ) = if      -1 [ exit, ] then
  0 ;

: ( 1 begin next-char is() + dup 0= until drop ; immediate

: 2dup over over ;
: 2drop drop drop ;
: 2over 3 pick 3 pick ;
: 3dup 2 pick 2 pick 2 pick ;
: 3drop drop 2drop ;

: cell 2 ;
: cells cell * ;

: binary 2 base ! ;
: decimal 10 base ! ;
: hex 16 base ! ;

: u/   u/mod nip ;
: umod u/mod drop ;
: /    /mod nip ;
: mod  /mod drop ;

: min 2dup > if swap then drop ;
: max 2dup < if swap then drop ;

\ ( value min max -- value )
: clamp rot min max ;
: within[] 2 pick >r clamp r> = ;
: within[) 1- within[] ;

: aligned dup cell mod + ;
: align   here @ aligned here ! ;

: :noname 0 0 define here @ ] ;
: >cfa    >terminator 1+ ;
: last    latest @ >cfa ;
: recurse jump, last xt, ; immediate

\ ===

: >body  6 + ;
: >does  >body 3 - ;
: does!  last >does xt! ;
: create word define something, return, exit, this! ;
: does>  something, ['] does! xt, exit, this! ; immediate

: allot here +! ;
: constant create , does> @ ;
: enum     dup constant 1+ ;
: flag     dup constant 1 lshift ;
: variable create cell allot ;

: idxer    create , does> @ + ;
: +field   over idxer + ;
: field    swap aligned swap +field ;

\ ===

: str-end? [char] " = ;

: string,
  next-char drop
  begin
    next-char dup str-end? 0=
  while
    c,
  repeat
  drop ;

: header, something, something, somewhere, rot this! ;
: s"      header, swap here @ string, how-far swap ! jump-mark! ; immediate

0 cell field >one
  cell field >two
constant size

0 >one
0 >two
size

##.s

: ext, ['] ext c, cell,l ;
: ##.s    [ 0x0001 ext, ] ;
: ##break [ 0x0001 ext, ] ;
: ##type  [ 0x0002 ext, ] ;
: ##cr    [ 0x0003 ext, ] ;
: ##mem   [ 0x0004 ext, ] ;

word hello ##type ##cr
##mem

\ : banner s" : mini ;" ##type ##cr ;

\ banner

bye

\ should this file have to end with 'bye' or 'quit' ?

\ including files needs an interpreter
\ unless...
\ including files can be done with devices

bye

