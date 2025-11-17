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
      { name: "exit", s_in: "", s_out: "", comment: "" },
      { name: "docol", s_in: "", s_out: "", comment: "" },
      { name: "docon", s_in: "", s_out: "", comment: "" },
      { name: "docre", s_in: "", s_out: "", comment: "" },
      { name: "jump", s_in: "", s_out: "", comment: "" },
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
        return `  ${wordName} ${stackEffect} ${word.comment}`
      } else {
        return `X ${wordName} ${stackEffect} deprecated ${word.deprecated}`
      }
    }).join("\n");

    console.log(wordList, longestNameLength);

    return `${vocab.name} definitions\n${wordList}\n\n`
  });

  return <div class="text-wrap text-xs overflow-y-auto whitespace-pre-wrap w-[80ch]">
    {body}
    {vocabularies}
  </div>
};
