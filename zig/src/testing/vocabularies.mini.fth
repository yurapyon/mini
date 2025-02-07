\ max 255 vocabularies
\ 0xff means stop search

variable current

2 value wordlist-id
: wordlist wordlist-id 1 +to wordlist-id ;

: vocabulary create wordlist , does> @ context ! ;

: definitions context @ current ! ;
