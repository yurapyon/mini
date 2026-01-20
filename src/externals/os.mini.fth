external sleep
external sleeps
external get-env
external cwd

external time-utc
\ todo get timezone and daylight savings somehow
-6 value hour-adj
: 24>12     12 mod dup 0= if drop 12 then ;
: time      time-utc flip hour-adj + 24 mod flip ;
: 00:#      # # drop ':' hold ;
: .time24   <# 00:# 00:# # # #> type ;
: .time12hm drop <# 00:# 24>12 # # #> type ;

external shell
: $ source-rest -leading 2dup shell ." exec: " type cr [compile] \ ;

external accept-file
: include source-rest 1/string source-len @ >in ! accept-file ;
