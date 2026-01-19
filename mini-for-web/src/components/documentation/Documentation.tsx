interface WordDefinition {
  name: string;
  s_in?: string;
  s_out?: string;
  expect_input?: string;
  comment?: string;
  deprecated?: string;
}

interface VocabularyDefinition {
  name: string;
  words: WordDefinition[];
}

const wordIndex: VocabularyDefinition[] = [
  {
    name: "forth",
    words: [
      { name: "exit", },
      { name: "docol", },
      { name: "docon", },
      { name: "docre", },
      { name: "jump", },
      { name: "jump0", },
      { name: "lit", },
      { name: "panic", },
      { name: "accept", },
      { name: "emit", },
      { name: "=", },
      { name: ">", },
      { name: ">=", },
      { name: "0=", },
      { name: "<", },
      { name: "<=", },
      { name: "u>", },
      { name: "u>=", },
      { name: "u<", },
      { name: "u<=", },
      { name: "and", },
      { name: "or", },
      { name: "xor", },
      { name: "invert", },
      { name: "lshift", },
      { name: "rshift", },
      { name: "!", },
      { name: "+!", },
      { name: "@", },
      { name: "c!", },
      { name: "+c!", },
      { name: "c@", },
      { name: ">r", },
      { name: "r>", },
      { name: "r@", },
      { name: "+", },
      { name: "-", },
      { name: "*", },
      { name: "/", },
      { name: "mod", },
      { name: "/mod", },
      { name: "*/", },
      { name: "*/mod", },
      { name: "u/", },
      { name: "umod", },
      { name: "1+", },
      { name: "1-", },
      { name: "negate", },
      { name: "drop", },
      { name: "dup", },
      { name: "?dup", },
      { name: "swap", },
      { name: "flip", },
      { name: "over", },
      { name: "nip", },
      { name: "tuck", },
      { name: "rot", },
      { name: "-rot", },
      { name: "move", },
      { name: "mem=", },
      { name: "rclear", },
      { name: "extid", },
      { name: "bl", },
      { name: "cell", },
      { name: "false", },
      { name: "true", },
      { name: "eof", },
      { name: "stay", },
      { name: "source-ptr", },
      { name: "source-len", },
      { name: ">in", },
      { name: "input-buffer", },
      { name: "h", },
      { name: "current", },
      { name: "context", },
      { name: "fvocab", },
      { name: "cvocab", },
      { name: "state", },
      { name: "base", },
      { name: "s*", },
      { name: "s0", },
      { name: "r*", },
      { name: "r0", },
      { name: "wnf", },
      { name: "2dup", },
      { name: "2drop", },
      { name: "3dup", },
      { name: "source", },
      { name: "source@", },
      { name: "next-char", },
      { name: "source-rest", },
      { name: "1/string", },
      { name: "-leading", },
      { name: "range", },
      { name: "token", },
      { name: "word", },
      { name: "c@+", },
      { name: "name", },
      { name: "string=", },
      { name: "locate", },
      { name: "find", },
      { name: "here", },
      { name: "pad", },
      { name: "str>char", },
      { name: "str>neg", },
      { name: "str>base", },
      { name: "in[,]", },
      { name: "char>digit", },
      { name: "str>number", },
      { name: ">number", },
      { name: "allot", },
      { name: ",", },
      { name: "c,", },
      { name: "lit,", },
      { name: "execute", },
      { name: "aligned", },
      { name: "align", },
      { name: ">cfa", },
      { name: "refill", },
      { name: "word!", },
      { name: "cfind", },
      { name: "interpret", },
      { name: "quit", },
      { name: "abort", },
      { name: "bye", },
      { name: "define", },
      { name: "external", },
      { name: "'", },
      { name: "]", },
      { name: ":", },
      { name: "\\", },
      { name: "forth", },
      { name: "compiler", },
      { name: "definitions", },
      { name: "cells", },
      { name: "@+", },
      { name: "c@+", },
      { name: "!+", },
      { name: "c!+", },
      { name: "<>", },
      { name: "2swap", },
      { name: "3drop", },
      { name: "space", },
      { name: "cr", },
      { name: "constant", },
      { name: "enum", },
      { name: "flag", },
      { name: "create", },
      { name: "variable", },
      { name: "loop*", },
      { name: "set-loop", },
      { name: ":", },
      { name: "(later),", },
      { name: "(lit),", },
      { name: "this", },
      { name: "this!", },
      { name: "dist", },
      { name: "(", },
      { name: ":noname", },
      { name: "last", },
      { name: ">does", },
      { name: "does>", },
      { name: ">value", },
      { name: "noop", },
      { name: "doer", },
      { name: "make*", },
      { name: "make", },
      { name: "undo", },
      { name: "value", },
      { name: "to", },
      { name: "+to", },
      { name: "vocabulary", },
      { name: "s[", },
      { name: "]s", },
      { name: "+field", },
      { name: "field", },
      { name: "type", },
      { name: "binary", },
      { name: "hex", },
      { name: "decimal", },
      { name: "min", },
      { name: "max", },
      { name: "%lt", },
      { name: "%eq", },
      { name: "%gt", },
      { name: "compare", },
      { name: "clamp", },
      { name: "in[,]", },
      { name: "in[,)", },
      { name: "/string", },
      { name: "next-digit", },
      { name: "next-byte", },
      { name: "escape,", },
      { name: "string", },
      { name: "cstring", },
      { name: "count", },
      { name: "(data),", },
      { name: "d\"", },
      { name: "c\"", },
      { name: "s\"", },
      { name: ".\"", },
      { name: "digit>char", },
      { name: "#start", },
      { name: "#len", },
      { name: "<#", },
      { name: "#>", },
      { name: "hold", },
      { name: "#", },
      { name: "#s", },
      { name: "#pad", },
      { name: "h#", },
      { name: "u.pad", },
      { name: "u.r", },
      { name: "u.0", },
      { name: "u.", },
      { name: ".", },
      { name: "printable", },
      { name: "print", },
      { name: ".byte", },
      { name: ".short", },
      { name: ".cells", },
      { name: "sdata", },
      { name: "depth", },
      { name: ".s", },
      { name: "rdata", },
      { name: "rdepth", },
      { name: ".r", },
      { name: "spaces", },
      { name: "[]", },
      { name: "ctlcode", },
      { name: ".ascii", },
      { name: ".col", },
      { name: ".row", },
      { name: "ashy", },
      { name: "split", },
      { name: ".bytes", },
      { name: ".print", },
      { name: "dump", },
      { name: ".word", },
      { name: "words", },
      { name: "[if]", },
      { name: "[then]", },
      { name: "[defined]", },
      { name: "sleep", },
      { name: "sleeps", },
      { name: "get-env", },
      { name: "cwd", },
      { name: "time-utc", },
      { name: "hour-adj", },
      { name: "24>12", },
      { name: "time", },
      { name: "00:#", },
      { name: ".time24", },
      { name: ".time12hm", },
      { name: "shell", },
      { name: "$", },
      { name: "accept-file", },
      { name: "include", },
      { name: "f+", },
      { name: "f-", },
      { name: "f*", },
      { name: "f/", },
      { name: "f>str", },
      { name: "str>f", },
      { name: "fswap", },
      { name: "fdrop", },
      { name: "fdup", },
      { name: "fbuf", },
      { name: "f.", },
      { name: "F", },
      { name: "f,", },
      { name: "f@", },
      { name: "fconstant", },
      { name: "u>f", },
      { name: "s>mem", },
      { name: "tags*", },
      { name: "tags,", },
      { name: "tag", },
      { name: "allocate", },
      { name: "free", },
      { name: "reallocate", },
      { name: "dyn!", },
      { name: "dyn+!", },
      { name: "dyn@", },
      { name: "dync!", },
      { name: "dyn+c!", },
      { name: "dync@", },
      { name: ">dyn", },
      { name: "dyn>", },
      { name: "dynmove", },
      { name: "fill", },
      { name: "erase", },
      { name: "blank", },
      { name: "src@", },
      { name: "src!", },
      { name: "evaluate", },
    ]
  },
  {
    name: "compiler",
    words: [
      { name: "[", s_in: "", s_out: "", comment: "" },
      { name: ";", s_in: "", s_out: "", comment: "" },
      { name: "literal", s_in: "", s_out: "", comment: "" },
      { name: "[compile]", s_in: "", s_out: "", comment: "" },
      { name: "[']", s_in: "", s_out: "", comment: "" },
      { name: "|:", s_in: "", s_out: "", comment: "" },
      { name: "loop", s_in: "", s_out: "", comment: "" },
      { name: "if", s_in: "", s_out: "", comment: "" },
      { name: "else", s_in: "", s_out: "", comment: "" },
      { name: "then", s_in: "", s_out: "", comment: "" },
      { name: "u>?|:", s_in: "", s_out: "", deprecated: "in favor of 'check>'"},
      { name: "dup>?|:", s_in: "", s_out: "", deprecated: "in favor of 'check!0'" },
      { name: "check>", s_in: "", s_out: "", comment: "" },
      { name: "check!0", s_in: "", s_out: "", comment: "" },
      { name: "cond", s_in: "", s_out: "0", comment: "" },
      { name: "endcond", s_in: "0 ...", s_out: "", comment: "" },
      { name: "tailcall", expect_input: "name", comment: "" },
      { name: "(", s_in: "", s_out: "", comment: "" },
      { name: "\\", s_in: "", s_out: "", comment: "" },
      { name: "[:", s_in: "", s_out: "", comment: "" },
      { name: ";]", s_in: "", s_out: "", comment: "" },
      { name: "does>", s_in: "", s_out: "", comment: "" },
      { name: "make", s_in: "", s_out: "", comment: "" },
      { name: ";and", s_in: "", s_out: "", comment: "" },
      { name: "to", s_in: "", s_out: "", comment: "" },
      { name: "+to", s_in: "", s_out: "", comment: "" },
      { name: "d\"", },
      { name: "c\"", },
      { name: "s\"", },
      { name: ".\"", },
      { name: "[if]", s_in: "", s_out: "", comment: "" },
      { name: "[then]", s_in: "", s_out: "", comment: "" },
      { name: "[defined]", s_in: "", s_out: "", comment: "" },
      { name: "F", s_in: "", s_out: "", comment: "" },
      { name: "@0", s_in: "", s_out: "", comment: "" },
      { name: "@1", s_in: "", s_out: "", comment: "" },
      { name: "@2", s_in: "", s_out: "", comment: "" },
      { name: "@3", s_in: "", s_out: "", comment: "" },
      { name: "@4", s_in: "", s_out: "", comment: "" },
      { name: "@5", s_in: "", s_out: "", comment: "" },
      { name: "@6", s_in: "", s_out: "", comment: "" },
      { name: "@7", s_in: "", s_out: "", comment: "" },
    ]
  }
];


export const Documentation = () => {
  const body = `=== mini specification ===

vm:
  cell size:     2 bytes
  address space: 64k bytes
  endianness:    little
  negatives:     twos compilment
  threading:     token threaded
  type system:   untyped

language:
  case-sensitive
  max input line length: 128 chars
  max word name length:  256 chars
  max numeric base:      36

opcodes (u16) :
  exit   docol  docon docre
  jump   jump0  lit   panic
  accept emit   =     >
  >=     0=     <     <=
  u>     u>=    u<    u<=
  and    or     xor   invert
  lshift rshift !     +!
  @      c!     +c!   c@
  >r     r>     r@    +
  -      *      /     mod
  /mod   */     */mod u/
  umod   1+     1-    negate
  drop   dup    ?dup  swap
  flip   over   nip   tuck
  rot    -rot   move  mem=
  rclear extid

non-standard opcodes:
  jump   - ( -- )                absolute jump
  jump0  - ( -- )                absolute conditional jump
  lit    - ( -- )                pushes following cell in memory to the stack
  rclear - ( xt -- )             clears return stack and executes xt
  extid  - ( str len -- number ) gets system specific id for an external function
  mem=   - ( a b len -- t/f )    compares memory
  panic  - ( -- )                dies
  flip   - ( a b c -- c b a )

memory layout:
0x0000      cell: program counter
            cell: address of currently executing xt
            cell: data stack *
            cell: return stack *
         2 cells: execution register
            cell: xt to init on forth start
            cell: stay, 'bye' sets this to false
            cell: h
            cell: forth vocabulary last
            cell: compiler vocabulary last
            cell: current
            cell: context
            cell: state
            cell: base
            cell: source-ptr
            cell: source-len
            cell: >in
            cell: vector to run when word not found
                : dictionary start

                .
                .
                .

                : data stack top
       128 bytes: input-buffer
        64 cells: return stack bottom
                : return stack top
0xffff      cell: _space

definition layouts:
  definition header:
    align(2)                                                align(2)
    |       0               16      24                      |
    |align--|previous-------|namelen|.......|.......|align--|

  ':':      ...header--|docol-----------|
  constant: ...header--|docon-----------|n---------------|
  create:   ...header--|docre-----------|does*-----------|
  value:    ...header--|docre-----------|value-does*-----|n---------------|

notable design decisions:
  only one, recursion-based, looping construct, '|:' and 'loop'
  compiler vocabulary is used instead of 'immediate'
  definitions are never 'hidden'
  variables must be initialized
  all string types accept escapes
  space and newline are the only whitespace characters supported as input

string escapes:
  \\0   - null
  \\t   - tab
  \\n   - newline
  \\N   - newline, refills interpreter, allowing for multiline string
  \\x?? - raw byte
  \\&   - refills interpreter, allowing for multiline string

number parsing:
  base modifiers:
    % - binary
    # - decimal
    $ - hexidecimal
  sign must come before base modifier, i.e. -$beef

=== control structures ===

if else then

cond endcond

|: loop
check> if ... loop then
check!0 if ... loop then

[if] [then] [defined]

=== defining words ===

doer make ;and undo

=== word index ===

`
  const vocabularies = wordIndex.map((vocab) => {
    const longestNameLength = vocab.words.reduce((acc, current) => {
      return Math.max(current.name.length, acc)
    }, 0);

    const wordList = vocab.words.map((word) => {
      const wordName = word.name.padEnd(longestNameLength);
      const isDeprecated = !!word.deprecated;

      const stackEffect = [
        "(",
        word.s_in ? ` ${word.s_in}` : "",
        word.expect_input && ` "${word.expect_input}"`,
        " -- ",
        word.s_out ? `${word.s_out} ` : "",
        ")"
      ].join("");

      if (!isDeprecated) {
        return `  ${wordName} ${stackEffect} ${word.comment || ""}`
      } else {
        return `X ${wordName} ${stackEffect} deprecated ${word.deprecated}`
      }
    }).join("\n");

    // TODO
    // console.log(wordList, longestNameLength);

    return `${vocab.name} definitions\n${wordList}\n\n`
  });

  return <div class="text-wrap text-xs overflow-y-auto whitespace-pre-wrap w-[80ch]">
    {body}
    {vocabularies}
  </div>
};
