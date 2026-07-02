# 0014 — Report-grade lexical metrics via bounded top-churn sampling

- **Status**: Accepted
- **Date**: 2026-07-02
- **Deciders**: rw_git maintainers
- **Related**: [ADR-0005](0005-server-side-interpretation-and-report-meta-tools.md)
  (the interpretation layer this feeds),
  [ADR-0003](0003-offload-cpu-bound-parsing-to-isolates.md) (isolate rule the
  sampler follows),
  [ADR-0010](0010-interpretation-threshold-change-process.md) (band change
  process)

## Context

The language-agnostic lexical metrics engine (genuine McCabe cyclomatic
complexity, maintainability index, Halstead, cognitive complexity) was
reachable only through the per-file `calculate_universal_lexical_metrics`
tool. No generated report ever consumed it: report "complexity" was a
git-diff control-flow keyword count — useful, but repo-relative and not the
research-grade metric the project cites. Running the lexer over every file
in a repository would make report latency unbounded, which is why the
engine had stayed out of the orchestrator.

## Decision

- A `BoundedLexicalMetricsSampler`
  (`lib/src/intelligence/static_analysis/metrics/bounded_lexical_metrics_sampler.dart`)
  lexes only the **top-N files by churn** (`maxLexicalMetricsFilesPerReport`,
  10). Churn is already computed by the orchestrator, so the sample costs no
  extra git calls — only N bounded file reads. The rationale for churn as
  the sampling key: defects concentrate where change concentrates (Nagappan
  & Ball, ICSE 2005), so the highest-churn files are precisely where
  complexity is most actionable.
- Files above `maxLexicalMetricsFileSizeBytes` (256 KiB) are skipped —
  almost always generated or vendored code — as are deleted/unreadable
  files. Paths are resolved against the canonical repository directory and
  anything escaping it is skipped (SECURITY.md).
- Lexing runs inside `Isolate.run` (ADR-0003: CPU-bound work off the main
  isolate).
- The `LexicalComplexityClassifier` applies **absolute** standard bands —
  McCabe > 10/20/50 → Elevated/High/Critical (McCabe, 1976); MI < 85/65 →
  Elevated/High (Coleman et al., 1994) — while the diff-keyword
  `complexity` category stays **repo-relative**. The two categories coexist
  deliberately: the keyword proxy sees every changed file cheaply; the
  genuine metrics are precise but sampled. Compound Rule 5
  (`real_complexity_x_churn`, Critical) joins the genuine metric with churn.
- Wired into `_technicalFindings` (technical report + repository audit) and
  `codeReviewReport`. The DTO (`FileLexicalMetricsDto`) preserves the churn
  path verbatim so `PathKey.normalize` yields the same join subject across
  classifiers.

## Consequences

- **Positive**: the project's most research-grade metrics finally reach the
  reports, with token cost unchanged (findings ride the existing bounded
  payload) and runtime bounded by constants.
- **Positive**: absolute McCabe/MI bands give reports industry-standard
  language ("effectively untestable") instead of only repo-relative ratios.
- **Negative / trade-off**: files outside the top-churn sample get no
  genuine-metric finding even if complex. Accepted: static complexity in
  rarely-touched code is a dormant risk, and the per-file deep-dive tool
  remains available; raising N is a one-constant change under the ADR-0010
  process.
