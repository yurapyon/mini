0 value mx
0 value my

: mousemove to my to mx ;

: mousedown .2 cr ;

' mousemove 2 sysxt!
' mousedown 3 sysxt!

: keydown . cr ;

create buf 128 allot
buf variable buf-at

: chardown 
  nip 0x7f and buf-at @ c! 1 buf-at +!
  buf 64 range .print cr
;

\ ' keydown 1 sysxt!
' chardown 4 sysxt!
