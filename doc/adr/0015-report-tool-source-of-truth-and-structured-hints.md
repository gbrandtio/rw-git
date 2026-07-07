# 0015 — Report tool source-of-truth map and structured, uncapped report hints

- **Status**: Accepted
- **Date**: 2026-07-03
- **Deciders**: rw_git maintainers
- **Related**: [ADR-0005](0005-server-side-interpretation-and-report-meta-tools.md)
  (the report meta-tools this touches),
  [ADR-0002](0002-mcp-tool-metadata-decorator.md) (the raw-tool `hints`
  mechanism this now matches)

## Context

`toolHintsCatalog` (`lib/src/intelligence/interpretation/
tool_hints_catalog.dart`) gives every research-grounded MCP tool a
`pair_with` entry: which other tool an analysis is designed to be read
alongside. Two independent consumers of this catalog had drifted apart:

- Raw single-tool calls, via `McpToolHintsDecorator`, spliced the tool's
  *full* `ToolHints` (all three categories) into the response.
- Report meta-tools (`generate_technical_report`, etc.) aggregated hints via
  `ReportPayload._selectHints`, which picked **one** string total per
  contributing tool — a caveat always won over a pair_with suggestion for
  the same tool — and capped the combined list at 6, regardless of how many
  analyses fed the report (`generate_repository_audit` unions ~13).
- Each reporting skill's `<deep_dive>` block hand-wrote, in prose, which raw
  tools a capable model could call for that report. This prose duplicated
  knowledge the catalog and `ReportOrchestrator` already encoded, and had
  already drifted from what each report actually runs: technical-reporting's
  list omitted `analyze_file_ownership` (used); pm-reporting's omitted
  `analyze_bug_hotspots` (used) and listed `analyze_release_delta` (never
  called); code-review-reporting's listed `analyze_pr_diff`/
  `evaluate_comments` (never called) and omitted `analyze_code_quality`/
  `detect_secrets_in_commits`/`analyze_bug_hotspots`/
  `analyze_file_ownership` (all used); the top-level audit skill's listed
  `analyze_architecture_drift` (never called).

Separately, `predict_merge_conflicts` was the only report-feeding tool whose
contribution was fully opt-in — it only produced findings for
`generate_code_review_report` when both `base_branch` and `target_branch`
were supplied — and its own catalog entry already documented that purely
textual three-way merge prediction misses or spuriously flags conflicts at a
substantial rate. Rather than special-case it in a new source-of-truth map,
it was removed entirely.

## Decision

- A new `reportToolSources` map
  (`lib/src/intelligence/interpretation/report_tool_sources.dart`) is the
  single, hand-maintained-but-tested source of truth for "which catalog
  tools feed this report type." `test/intelligence/interpretation/
  report_tool_sources_test.dart` cross-checks it, via static source-text
  inspection of `report_orchestrator.dart` (chosen over a live repository
  run, which would be flaky — a report's one contributing commit history
  might produce zero material findings for some source even though its
  classifier genuinely runs), against every classifier `ReportOrchestrator`
  actually invokes per report.
- `tool/prompt_codegen.dart` gains a `<!-- generate:deep_dive_tools
  report=... -->` template marker (`expandGenerated`, `renderDeepDiveTools`),
  parallel to the existing `<!-- include:... -->` mechanism but sourced from
  Dart data (`reportToolSources`) instead of a static partial file. Every
  reporting skill's `<deep_dive>` raw-tool list is now generated from this
  marker instead of hand-written prose. `test/mcp/prompts_sync_test.dart`
  asserts the generated list matches the map exactly, in order, closing the
  drift class described above.
- `ReportPayload.hints` changes from `List<String>` to a new `ReportHints`
  class (`lib/src/intelligence/interpretation/report_hints.dart`) mirroring
  `ToolHints`'s three-category shape. The new aggregation
  (`ReportPayload._aggregateHints`) collects every distinct
  interpretation/caveat/pair_with string from every contributing tool's
  catalog entry — not one string picked per tool — deduplicated per
  category and deliberately uncapped, so a pair_with suggestion can never
  be crowded out by that same tool's own caveat, and a report composing
  many analyses (e.g. the repository audit) surfaces all of their guidance
  rather than an arbitrary slice of it.
- `predict_merge_conflicts`, `ConflictRiskHeuristic`, and
  `ConflictRiskClassifier` are removed, along with the
  `base_branch`/`target_branch` parameters of `generate_code_review_report`
  that existed solely to feed it, and Compound Rule 6 (predicted conflict ×
  bug hotspot).

## Consequences

- **Positive**: report `hints` and skill deep-dive tool lists both now
  read, transitively, from the same catalog data that drives raw-tool
  hints — the three surfaces cannot diverge from each other going forward,
  and two regression tests enforce it.
- **Positive**: a caveat no longer hides a pair_with suggestion for the
  same tool in report output, restoring the cross-tool navigation signal
  `pair_with` is meant to provide.
- **Negative / breaking**: `hints` in every `generate_*_report` response
  changes shape from a flat string array to an object with
  `interpretation`/`caveats`/`pair_with` keys. This is a wire-format break
  for any existing consumer of report JSON; documented in `CHANGELOG.md` and
  released as `3.2.0`.
- **Negative / trade-off**: report hints are now uncapped, so a report
  composing many analyses (the repository audit) can return a longer
  `hints` object than before. Accepted: the alternative (an arbitrary cap)
  is exactly the mechanism that caused the pair_with-shadowing defect this
  ADR fixes.
- **Addendum**: the offload `preview` built by `McpToolFileOffloadDecorator`
  (`_carryHints`) originally re-capped this same prioritized hints list to
  keep the recurring inline cost of every offloaded call bounded. That cap
  is removed — the preview now carries the full prioritized hints list
  (caveats, then pair_with, then interpretation), matching the uncapped
  full-report contract above rather than reintroducing a second, smaller
  cap on top of it.
- **New dependency edge**: `tool/prompt_codegen.dart` (previously
  dependency-free beyond Dart core) now imports
  `package:rw_git/src/intelligence/interpretation/report_tool_sources.dart`.
