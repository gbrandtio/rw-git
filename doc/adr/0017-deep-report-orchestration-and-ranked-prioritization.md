# 0017 — Deep report orchestration and ranked hotspot prioritization

- **Status**: Accepted
- **Date**: 2026-07-06
- **Deciders**: rw_git maintainers
- **Related**: [ADR-0005](0005-server-side-interpretation-and-report-meta-tools.md)
  (the meta-tool architecture this deepens),
  [ADR-0010](0010-interpretation-threshold-change-process.md)
  (the threshold-change process every new band followed),
  [ADR-0014](0014-report-grade-lexical-metrics-bounding.md)
  (the bounded sample the new analyses reuse),
  [ADR-0015](0015-report-tool-source-of-truth-and-structured-hints.md)
  (`reportToolSources` and hint routing)

## Context

The report meta-tools consumed roughly half of the library's
research-backed signal surface. Of the six lexical-complexity metrics the
agnostic suite implements, only McCabe and the maintainability index
reached any report — ABC (Fitzpatrick 1997), NPath (Nejmeh 1988),
cognitive complexity (Campbell 2018), and the Halstead delivered-bugs
estimate (Halstead 1977) were computed by `calculate_universal_lexical_metrics`
but dropped by the bounded sampler's DTO. `analyze_architecture_drift`,
`analyze_clean_code`, and `analyze_dart_ast_quality` fed no report at all,
with their analysis logic embedded in the tool classes rather than the
library (against ADR-0005's library-first rule). The correlator had five
compound rules, all boolean per-file joins — no ranked prioritization, no
author-level aggregation, no delivery-health join. Structurally, the
orchestrator ran strictly sequentially, ran `git log -p` twice per
technical/code-review report (once for churn, once for churn-with-authors,
which parses the identical output), skipped the RA-SZZ refactoring
discount in the code-review path, and compound findings contributed no
`hints` because their joined `"a + b"` source string matched no
`toolHintsCatalog` key. Separately, `analyze_pr_diff`'s composite score
duplicated signals the reports now classify individually, and stale
references to it and to the removed `predict_merge_conflicts` lingered in
descriptions and the interpretation guide.

## Decision

- **Full lexical suite**: `FileLexicalMetricsDto` and the bounded sampler
  carry ABC, NPath, cognitive complexity, and Halstead delivered-bugs
  alongside McCabe/MI. The lexical classifier bands every metric
  independently (named constants per ADR-0010) and emits one finding per
  file carrying the worst-banding metric with the full suite in evidence.
- **Library-first extraction + new classifiers**: the architecture-drift
  and clean-code analyses move into
  `lib/src/intelligence/architecture/architecture_drift_algorithm.dart`
  and `lib/src/intelligence/static_analysis/clean_code_analyzer.dart`;
  their MCP tools become thin wrappers with unchanged wire formats. New
  classifiers band Garcia et al. (2009) smells, coupling ratio/density,
  clean-code heuristics (with a new duplicate-lines issue), and Tarjan
  import cycles (Dart repos only, gated on `pubspec.yaml`). Report-grade
  architecture drift infers layers from the churned file paths
  (`inferLayerPatterns`), so no caller-supplied layer map is needed.
- **Ranked prioritization**: `ReportPayload` gains an additive
  `refactoring_targets` field — Tornhill's churn-percentile x
  complexity-percentile map (Tornhill 2015; Ostrand, Weyuker & Bell 2004),
  genuine McCabe preferred over the proxy with each metric percentiled
  within its own population, minimum product 0.25, top 5.
- **Three new compound rules**: author-level knowledge loss (one author
  solely owning 2+ hotspot files → Critical), minor-contributors x hotspot
  (High; the ownership classifier now emits Bird's minor-contributor
  finding), and burnout x bug-introduction (High). The burnout rule is
  deliberately a repo-level co-occurrence of two already-classified
  findings, not a per-commit causal join: SZZ dates are UTC-normalized
  while the burnout window is author wall-clock, and joining the two time
  bases per commit would fabricate precision.
- **Structural fixes**: one `git log -p` pass per report (plain churn
  totals derived from the per-author breakdown); the code-review report
  applies the refactoring-context downgrade; independent analyses start
  eagerly and run concurrently (read-only git subprocesses; CPU-bound
  parsing stays in isolates per ADR-0003); `_aggregateHints` splits
  compound source strings on `' + '` so compounds finally contribute
  hints; the audit additionally runs commit velocity so the burnout rule
  can fire there.
- **Removal**: `analyze_pr_diff` is deleted (tool, registration, doc,
  catalog entry, export) and every stale `analyze_pr_diff` /
  `predict_merge_conflicts` reference is purged.

## Consequences

- **Positive**: the reports now consume the library's full deterministic
  signal surface; every new band and rule carries named constants, unit
  tests, interpretation-guide sections, and citations in the same change
  set (ADR-0010), and `reportToolSources` plus its drift guards were
  extended in lockstep (ADR-0015).
- **Positive**: `refactoring_targets` turns per-file boolean findings into
  the ordered "refactor these first" answer — the highest-business-value
  artifact a technical report can carry, at zero additional git cost.
- **Negative / breaking**: `analyze_pr_diff` disappears from `tools/list`.
  Documented in `CHANGELOG.md` under `3.2.0`; the code-review report and
  the individual raw tools cover its constituent signals.
- **Trade-off**: report payloads grow (new finding categories,
  `refactoring_targets`). Accepted: the caps (`maxTopFindings`,
  `maxCompoundFindings`, `maxRefactoringTargets`) bound the inline size,
  and the 4 KiB report offload threshold (ADR-0011) is unchanged.
- **Trade-off**: inferred architecture layers are a heuristic (generic
  containers descended, tests/docs excluded, top-8 by file count).
  Accepted: raw-tool callers keep full control via `layer_patterns`;
  reports need a deterministic zero-configuration default, and a wrong
  inference degrades to zero findings rather than wrong bands.
