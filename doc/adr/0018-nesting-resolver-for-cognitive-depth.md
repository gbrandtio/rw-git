# 0018 — Shared nesting resolver for cognitive depth

- **Status**: Accepted
- **Date**: 2026-07-12
- **Deciders**: rw_git maintainers
- **Related**: [ADR-0014](0014-report-grade-lexical-metrics-bounding.md)
  (the bounded sample these metrics feed)

## Context

Cognitive complexity penalizes nested control flow (`1 + nesting depth` per
branch), so its value hinges on knowing the depth. The previous
implementation guessed depth inside each algorithm by counting every
`{ [ (` as +1 and every `} ] )` as -1. This produced three classes of wrong
answers:

1. **Inflated baselines in brace languages.** Function bodies, argument
   lists, and collection literals all counted as nesting, so a single flat
   `if` inside a function scored 2 instead of 1, and an `else` chain
   (`if/else if/else`) scored 8 where the SonarSource specification says 3.
2. **Zero signal in indentation languages.** Python has no braces; the
   lexer discarded leading whitespace, so a triple-nested
   `while → for → if` scored identically to three flat `if`s. The metric
   silently degenerated into cyclomatic counting.
3. **Duplicated, diverging logic.** `CognitiveComplexityAlgorithm` and
   `IndentationComplexityAlgorithm` each re-derived depth with slightly
   different rules and returned slightly different wrong answers.

## Decision

Nesting is a structural fact, computed once by a dedicated
`NestingResolver` sitting between the lexer and the algorithms. Its
strategy is declared per language on `LanguageProfile` via a new
`BlockStructure` enum:

- **`braces`** — a `{` opens a *control* frame only when it terminates a
  pending control-flow clause; a *lambda* frame when it follows a lambda
  introducer (`=>`, `->`) or a `)` inside an argument list; a *neutral*
  frame otherwise (function/class bodies, literals). Only control and
  lambda frames count as depth, mirroring the SonarSource rule that
  control structures and nested functions nest while method bodies do not.
  Parentheses and square brackets are expression grouping, never nesting.
- **`indentation`** — the lexer now stamps each newline token with the
  next line's indentation width (tabs expand to multiples of 8; blank and
  comment-only lines stamp -1). The resolver synthesizes indent/dedent
  events from a width stack — the classic Python tokenizer algorithm —
  ignoring lines inside open brackets (implicit continuation). Blocks
  opened by control-flow lines nest; blocks opened by `def`/`class` do not.
- **`keywordEnd`** — Ruby/Lua/shell blocks open with profile-declared
  keywords in statement position (first token of a line, which filters out
  modifier forms like `x = 1 if y`) and close with `end`/`fi`/`done`.
  Ruby's block `do` opens a lambda frame.

`CognitiveComplexityAlgorithm` was rewritten against the SonarSource
specification on top of the resolved depths: structural branches score
`1 + depth`; `else`/`elif` score a flat +1 with `else if` collapsed to one
increment; `switch` counts once and `case` arms do not; ternary `?` counts
(disambiguated from nullable-type markers by scanning for a same-level
`:`); `&&`/`||`/`??` and keyword `and`/`or` score +1; a control keyword
glued to `#` (C preprocessor `#if`) is ignored.
`IndentationComplexityAlgorithm` became a thin consumer of the same
resolution.

## Consequences

- Cognitive-complexity values change for every language: generally lower
  for brace languages (baseline deflation) and higher for Python (nesting
  is finally visible). Old and new scores are not comparable; downstream
  thresholds should be revisited against ADR-0010's process.
- The resolver is heuristic, not a parser. Known accepted approximations:
  Go composite literals in conditions, Ruby brace-blocks vs hash literals,
  Lua `repeat/until` double-counting, TypeScript optional-parameter `?:`.
  These are rare and bounded; full fidelity is the AST path's job.
- Depth truth lives in one place; future algorithms (NPath, cyclomatic
  variants) can adopt it without re-deriving structure.
