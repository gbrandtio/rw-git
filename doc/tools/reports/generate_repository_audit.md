# generate_repository_audit

## Business Logic

Answers: "What are the most important risks in this repository, across every axis at once?". A one-call, high-level deep audit combining the technical, security, and delivery dimensions in a single pass.

For example:
- A complexity outlier that also churns heavily.
- A stale major dependency whose config also leaks a secret.
- An author whose departure would orphan several bug hotspots.
- Sustained off-hours work alongside active hotspots.

This is a **report meta-tool** ([ADR-0005](../../adr/0005-server-side-interpretation-and-report-meta-tools.md)): classification and correlation happen via deterministic research-backed algorithms, not propagated for interpretation in the LLM. A small/local model produces a complete, band-classified, ranked report from a single tool call instead of orchestrating ~10 raw tools, reading offloaded files, and applying the interpretation guide itself.

## Algorithm

1. `ReportOrchestrator` runs the relevant analysis algorithms server-side. The algorithms running are producing results relevant to bus factor, ownership, Bird's minor-contributor structure (high-number of minor contributors has a strong, statistically significant relationship with an increase in pre-release and post-release failures), bug hotspots, complexity (utilizing the full genuine lexical suite), maintainability index, ABC, NPath, cognitive complexity, Halstead delivered-bugs on the top-churn files, churn, logical coupling, volatility, refactoring detection, architecture drift over inferred layers, clean-code heuristics, Dart import cycles (Dart repos only), commit velocity/burnout, commit hygiene (mega and suspicious commits), secrets, compliance, and dependency freshness. This is done by reusing the existing library-first algorithms and running the independent analyses concurrently.
2. Per-metric **classifiers** (`lib/src/intelligence/interpretation/classifiers/`) map each analysis DTO into severity-banded `Finding`s using the bands documented in [`doc/INTERPRETATION_GUIDE.md`](../../INTERPRETATION_GUIDE.md).
3. The `CompoundFindingCorrelator` applies the cross-tool AND-rules i.e., risks that only matter when two signals co-occur (author-level knowledge loss, minor-contributors-on-a-hotspot, and burnout alongside active hotspots).
4. Findings are ranked most-severe first and returned as a bounded `ReportPayload`, together with the ranked Tornhill `refactoring_targets` list (churn percentile × complexity percentile).

## Parameters

| Parameter | Required | Description |
| --- | --- | --- |
| `directory` | yes | The local repository path. |
| `limit` | no | Max recent commits to analyze (default: 500, see `defaultCommitLimit` in `lib/src/constants.dart`). |
| `branch` | no | Branch or commit range to scan for secrets. Defaults to current HEAD. |
| `check_freshness` | no | When `true`, performs network lookups against package registries to flag outdated dependencies. Default `false` (fully offline). |
| `allowed_emails` | no | Comma-separated allow-list of author emails for the compliance check. |
| `since` | no | Only commits after this date (ISO-8601, e.g. `2024-01-01`, or a git relative phrase, e.g. `6 months ago`). |
| `until` | no | Only commits before this date (ISO-8601, e.g. `2024-12-31`, or a git relative phrase, e.g. `yesterday`). |

The report can be scoped to a date window via `since`/`until`, which are forwarded verbatim to git's own `--since=`/`--until=` date parser — no natural-language date math is performed by `rw_git` itself.

## Output Contract

Shared by all five report meta-tools (advertised via the compact `_reportOutputSchema`, [ADR-0002](../../adr/0002-mcp-tool-metadata-decorator.md)):

- `report_type`: which report was generated.
- `summary`: finding counts by severity.
- `top_findings`: ranked array where each finding carries `severity`, `subject`, `band`, `metric`, `value`, a ready-to-use `message`, a compact `basis` citation tag naming the research behind the band (e.g. `Truck-factor estimation (Avelino et al. 2016)`), and a fuller `rationale` explaining why the metric predicts risk with the respective citation. The offload preview carries every finding in full, including `rationale`, so it stays actionable without a second file read.
- `compound_findings`: cross-tool correlated risks, the highest-priority items.
- `refactoring_targets`: present when the report has both churn and complexity signals (technical, code review, audit): source-code files ranked by churn percentile × complexity percentile (Tornhill 2015), the ordered "refactor these first" list. Non-code paths (prose, config, lockfiles) are excluded before percentiling. Hotspot prioritization is defined over source files, and prose diffs would otherwise match the keyword proxy.

If the payload exceeds the offload threshold ([ADR-0001](../../adr/0001-file-offloading-of-large-tool-outputs.md)), the offload `preview` still carries `summary`/`top_findings`/`compound_findings`, so the report stays actionable inline without a second file read.

## Foundations

The classification thresholds and compound-risk rules, and the related research each one is grounded in, are documented in [`doc/INTERPRETATION_GUIDE.md`](../../INTERPRETATION_GUIDE.md). The underlying metrics inherit the academic foundations of the raw tools this report orchestrates; see the per-tool documents under `doc/tools/` and the consolidated citation index in [`doc/tools/REFERENCES.md`](../REFERENCES.md).
