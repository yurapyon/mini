s" mini" type cr

0 value curr0 0 value f0 0 value c0 0 value u0
: empty curr0 current ! f0 wordlists !
        u0 here !       c0 wordlists cell + ! ;
current @ to curr0 wordlists @ to f0
here @ to u0       wordlists cell + @ to c0

[defined] empty-buffers [if] empty-buffers [then]
