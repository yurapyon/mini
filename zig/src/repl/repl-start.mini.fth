s" mini" count type cr

0 value l0 0 value f0 0 value c0 0 value u0
: empty l0 latest ! f0 wordlists !
        u0 here !   c0 wordlists cell + ! ;
latest @ to l0 wordlists @ to f0
here @ to u0   wordlists cell + @ to c0
