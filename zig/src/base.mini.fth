word docol# define ' docon @ , ' docol @ ,

word ] define docol# , ' lit , 1 , ' state , ' ! , ' exit ,
compiler-latest context ! context @ current !
word [ define docol# , ' lit , 0 , ' state , ' ! , ' exit ,
forth-latest context ! context @ current !

word : define docol# , ] word define docol# , ] [ ' exit ,
compiler-latest context ! context @ current !
: ; lit exit , [ ' [ , ' exit ,
forth-latest context ! context @ current !

: forth    forth-latest context ! ;
: compiler compiler-latest context ! ;
: definitions context @ current ! ;

: \ source-len @ >in ! ;

: negate 0 swap - ;

: 2dup  over over ;
: 2drop drop drop ;
: 2swap flip >r flip r> ;
: 3drop drop 2drop ;
: third >r over r> swap ;
: 3dup  third third third ;

: fourth >r third r> swap ;

: lit, lit lit , ;
compiler definitions
: literal lit, , ;
: [compile] ' , ;
: ['] ' [compile] literal ;
forth definitions

: constant word define ['] docon @ , , ;
: enum dup constant 1+ ;
: flag dup constant 1 lshift ;

2 constant cell
: cells cell * ;

: here    h @ ;
: allot   h +! ;
: aligned dup cell mod + ;
: align   here aligned h ! ;

: create word define ['] docre @ , ['] exit , ;

: variable create , ;

\ todo loop could be called recurse
0 variable loop*
: set-loop here loop* ! ;
compiler definitions
: |:   set-loop ;
: loop ['] jump , loop* @ , ;
forth definitions
: : : set-loop ;

: (later), here 0 , ;
: (lit),   lit, (later), ;

: this  here swap ;
: this! this ! ;
: dist  this - ;

compiler definitions
: if   ['] jump0 , (later), ;
: else ['] jump , (later), swap this! ;
: then this! ;

\ todo rename dorange / dolist
: do.u>   [compile] |: ['] 2dup , ['] u> , [compile] if ;
: do.u>=  [compile] |: ['] 2dup , ['] u>= , [compile] if ;
\ TODO replace this with do.dup
: do.?dup [compile] |: ['] ?dup , [compile] if ;
\ todo putting this inside an if/else/then breaks it
: godo    [compile] loop [compile] then ;

0 constant cond
: endcond do.?dup [compile] then godo ;
forth definitions

: ( next-char ')' = 0= if loop then ;
compiler definitions
: ( ( ; \ )
: \ \ ;
forth definitions

\ defining words ===

\ math ===

compiler definitions
: [by2] ' dup \ >r swap >r __ r> r> __
  ['] >r , ['] swap , ['] >r , , ['] r> , ['] r> , , ;
forth definitions

: binary 2 base ! ;
: decimal 10 base ! ;
: hex 16 base ! ;

: @+ dup cell + swap @ ;
: !+ tuck ! cell + ;
: c@+ dup 1+ swap c@ ;
: c!+ tuck c! 1+ ;

: <> = 0= ;
: min 2dup > if swap then drop ;
: max 2dup < if swap then drop ;

-1 enum %lt enum %eq constant %gt
: compare 2dup = if 2drop %eq else > if %gt else %lt then then ;

\ ( value min max -- value )
: clamp rot min max ;
: in[,] rot tuck >= -rot <= and ;
: in[,) 1- in[,] ;

: char word drop c@ ;

: char>digit cond
    dup '0' '9' in[,] if '0' - else
    dup 'A' 'Z' in[,] if '7' - else
    dup 'a' 'z' in[,] if 'W' - else
  endcond ;

: digit>char dup 10 < if '0' else 10 - 'a' then + ;

: split ( end start split -- end start+split start+split start )
  over + tuck swap ;

: range ( addr ct -- end-addr start-addr )
  over + swap ;

: slice ( start end addr -- addr ct )
  flip tuck - -rot + swap ;

: [] ( i spacing addr -- addr[i*spacing] spacing )
  flip over * rot + swap ;

\ strings ===

: (data), (lit), ['] jump , (later), swap this! ;

: next-digit next-char char>digit ;
: next-byte next-digit 16 * next-digit + ;

: escape, next-char cond
    dup '0' = if drop  0 c, else
    dup 't' = if drop  9 c, else
    dup 'n' = if drop 10 c, else
    dup 'N' = if drop 10 c, refill drop else
    dup 'x' = if drop next-byte c, else
    dup '&' = if drop refill drop else
    \ NOTE
    \ \\ and \" are handled by the 'cond' falling through
    c,
  endcond ;

: string next-char drop |:
  next-char cond
    dup '"' = if drop exit else
    dup '\' = if drop escape, else
    c,
  endcond loop then ;

: count @+ ;
: cstring (later), here string dist swap ! ;

: d" here dup string h ! ;
: c" here dup cstring h ! ;
: s" [compile] c" count ;
compiler definitions
: d" (data), string align this! ;
: c" (data), cstring align this! ;
: s" [compile] c" ['] count , ;
forth definitions

: string= rot over = if mem= else 3drop false then ;

\ number print ===

: pad here 64 + ;

\ TODO 'variable' is breaking
0 variable #start
: #len pad #start @ - ;
: <#   pad #start ! ;
: #>   drop #start @ #len ;
: hold -1 #start +! #start @ c! ;
: #    base @ /mod digit>char hold ;
: #s   dup 0= if # else |: # dup if loop then then ;
: #pad dup #len > if over hold loop then 2drop ;

\ todo
\   holds
\   sign

: h# 16 /mod digit>char hold ;

\ ===

: get-word word ?dup 0= if drop refill if loop else
  0 0 then then ;

\ todo
\ this behavior is weird and doesnt panic on EoF
: [if] 0= if |: get-word ?dup 0= if panic then
  s" [then]" string~= 0= if loop then then ;
: [then] ;
: [defined] word find nip ;

compiler definitions
: [if]      [if] ;
: [then]    [then] ;
: [defined] [defined] ;
forth definitions

\ ===

: name cell + c@+ ;
: >cfa name + aligned ;
: last current @ @ >cfa ;

: >does cell + ;
compiler definitions
: does> (lit), ['] last , ['] >does , ['] ! , ['] exit ,
  this! docol# , ;
forth definitions

: value create , does> @ ;
: vname ' 2 cells + ;
: to  vname ! ;
: +to vname +! ;
compiler definitions
: to  lit, vname , ['] ! , ;
: +to lit, vname , ['] +! , ;
forth definitions

: vocabulary create 0 , does> context ! ;

0 constant s[
: ]s constant ;
: +field over create , + does> @ + ;
: field  swap aligned swap +field ;

\ xts ===

: :noname 0 0 define here docol# , set-loop ] ;

compiler definitions
: [: lit, here 6 + , ['] jump , (later), docol# , ;
: ;] ['] exit , this! ;
forth definitions

: does> last :noname swap >does ! ;

\ ===

: mem d0 dist ;

: fill   >r range do.u> r@ swap c!+ godo r> 3drop ;
: fill16 >r range do.u> r@ swap  !+ godo r> 3drop ;
: erase 0 fill ;

: swapmem over @ over @ 2swap >r ! r> ! ;

( addr0 addr1 len -- )
: swapstrs >r over pad r@ move tuck swap r@ move
  pad swap r@ move r> drop ;

\ evaluation ===

vocabulary interpreter

: source source-ptr @ ?dup 0= if input-buffer then
  source-len @ ;

\ todo
\ test on loading blocks
\   just return the rest of the line? like '\'
: source-rest >in @ dup source drop + swap
  source-len @ swap - ;

' 2drop variable onwnf

\ note
\ saved-max is also used for blkstack
8 constant saved-max

interpreter definitions

: onlookup 0= state @ and if >cfa , else >cfa execute then ;
: onnumber state @ if lit, , then ;

: resolve cond
    2dup lookup  if 2swap 2drop onlookup else 2drop
    2dup >number if -rot  2drop onnumber else drop
    onwnf @ execute
  endcond ;

s[
  cell field >saved-ptr
  cell field >saved-len
  cell field >saved-at
]s saved-source

create saved-stack saved-max saved-source * allot
saved-stack value saved-tos

: save-source
  source-ptr @ saved-tos >saved-ptr !
  source-len @ saved-tos >saved-len !
  >in @        saved-tos >saved-at !
  saved-source +to saved-tos ;

: restore-source
  saved-source negate +to saved-tos
  saved-tos >saved-ptr @ source-ptr !
  saved-tos >saved-len @ source-len !
  saved-tos >saved-at @  >in ! ;

: set-source source-len ! source-ptr ! 0 >in ! ;

forth definitions
interpreter

: interpret get-word ?dup if resolve loop else drop then ;
: evaluate save-source set-source interpret restore-source ;

forth

\ ===

32 constant bl
: blank bl fill ;
: printable 32 126 in[,] ;
: ctlcode cond dup 32 u< if 3 d" \&
nulsohstxetxeotenqackbelbs ht lf vt ff cr so si dledc1dc2dc3dc\&
4naksynetbcanem subescfs gs rs us " [] else
  127 = if s" del" else 0 0 endcond ;

: findc >r do.u> dup c@ r@ <> if 1+ godo then swap r> 2drop ;
: cin[] third >r findc r> <> ;

( addr len 'c' -- t/f )
: in-string -rot range rot cin[] ;
: in-pad pad count rot in-string ;
: s>pad dup pad !+ swap move ;
: whitespace s"  \n\t" s>pad ;

( end start -- addr )
\ : token 2dup > if c@+ in-pad 0= if loop then then nip ;
\ : ltrim 2dup > if dup c@ in-pad if 1+ loop then then nip ;
\ : rtrim swap 1- |: 2dup <= if dup 1- c@ in-pad if 1- loop then
\  then nip ;

: -trailing dup if 2dup + 1- c@ bl = if 1- loop then then ;

( addr len n -- addr+n len-n )
: /string tuck - -rot + swap ;

: -leading dup if over c@ bl = if 1 /string loop then then ;

\ double buffers ===

\ todo db.fill
: double-buffer create false , dup , 2 * allot ;
: db.>s @+ swap @+ swap ;
: db.erase db.>s swap 2 * erase drop ;
: db.swap dup @ invert swap ! ;
: db.get db.>s rot >r rot r> xor if nip else + then ;

\ grid ===

: lastcol? ( i w -- t/f ) swap 1+ swap mod 0= ;
: xy>i     ( x y w -- i ) * + ;
: i>xy     ( i w -- x y ) /mod swap ;
: wrap     ( val max -- ) tuck + swap mod ;
: xy+    [by2] + ;
: wrapxy [by2] wrap ;

\ add two numbers but keep the value within 0-max
: keepin ( a b max -- newv ) -rot + 0 rot clamp ;

0 [if]

compiler
: assign (lit), ['] swap , ['] ! , ['] exit , this! docol# , ;
forth

: next, ['] jump , here cell + , ;
: dyn, define docol# , next, ;
: dyn! >cfa 2 cells + this! ;
: :dyn word find if drop dyn! else dyn, then ] ;

[then]
