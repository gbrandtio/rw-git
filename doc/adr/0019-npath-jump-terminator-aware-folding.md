# 0019 — NPath Jump-Terminator–Aware Folding

| Field    | Value                                                   |
|----------|---------------------------------------------------------|
| Status   | Accepted                                                |
| Date     | 2026-07-14                                              |
| Authors  | rw-git maintainers                                      |
| See also | Nejmeh (CACM 1988), PMD NPathComplexity, ADR-0018       |

## Context

The NPath metric (Nejmeh, 1988) counts acyclic execution paths through a
function by multiplying decision factors.  Sequential `if` statements each
contribute a factor of 2, so four guard clauses produce 2⁴ = 16 even when
each guard's `then` body terminates with `return` (or `throw`, `break`,
`continue`).  The terminated branches never reach downstream code, so the
real path count is only 4 (one per guard exit) + 1 (the fall-through
continuation) = 5 — not 16.

This is a documented criticism of the metric: PMD's `NPathComplexity` rule
documentation notes that guard clauses inflate the score, and multiple
academic treatments point out that the standard formula does not model
early exits.  The inflation penalises a universally recommended defensive
coding pattern (guard clauses), producing false positives against the
200-path threshold.

## Decision

When an `if` or `else-if` branch body ends with a **jump terminator** —
one of `return`, `throw`, `break`, `continue`, or `raise` — its paths
are folded **additively** into the parent scope's `terminatedPaths`
accumulator instead of being multiplied into the parent's `product`.
The fall-through continuation (the implicit `else` path, value 1)
continues to multiply normally into `product`.

At scope completion, the final NPath is `product + terminatedPaths`:
the multiplicative core of genuinely combinatorial decisions plus the
additive count of branches that exit early.

### Scope restriction

Additive folding applies **only** when all three conditions hold:

1. The scope's `_FoldKind` is `ifBranch` or `elseIfBranch`.
2. The scope's `endsWithJump` flag is `true` (the last statement-level
   token before the scope closed was a jump terminator).
3. The scope has **zero** boolean operators in its condition (`boolOps
   == 0`).  A guard clause with a compound condition (`if (a && b)
   return;`) has boolean-operator paths that are *not* terminated by the
   jump, so standard multiplicative folding must apply.

### Jump-terminator detection

Jump terminators are detected as **identifiers** at `_exprDepth == 0`
(statement level), not as control-flow keywords.  This works uniformly
across all three `BlockStructure` modes (braces, indentation,
keyword-end) because `return`, `throw`, `break`, `continue`, and `raise`
are language-universal identifiers that the lexer emits as
`TokenType.identifier`.

For braceless bodies (`if (a) return;`), the pending-decision tracker
(`_pendingEndsWithJump`) propagates the flag to `_resolvePendingAsLeaf`,
which stamps the synthetic leaf scope before `_fold` processes it.

## Consequences

### Positive

- Guard-clause-heavy functions score accurately.  Four sequential
  guards now score 5 instead of 16; the `createApp` example that
  motivated this change drops from ~1,080 to ~64.
- The 200/1000 thresholds remain unchanged — the correction makes the
  metric more accurate, not more lenient.
- Well-structured code is rewarded instead of penalised.

### Negative

- NPath values are **not comparable** with PMD or pre-change rw-git
  values for functions that contain guard clauses.  This is a breaking
  change that must be called out in the changelog.
- Tool documentation must note the divergence for users who compare
  rw-git NPath with PMD NPath.

### Neutral

- Functions without jump terminators in their branch bodies produce
  identical scores to the standard Nejmeh/PMD computation.
- The `_jumpTerminators` set is a static constant; runtime cost is a
  single hash-set lookup per identifier token at `_exprDepth == 0`.
