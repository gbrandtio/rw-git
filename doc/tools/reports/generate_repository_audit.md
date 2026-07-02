# generate_repository_audit

## Business Logic

Answers: "What are the most important risks in this repository, across every axis at once?" A one-call, high-level deep audit combining the technical and security dimensions in a single pass — the pass where cross-tool **compound findings** surface best (e.g. a complexity outlier that also churns heavily, or a stale major dependency whose config also leaks a secret).

This is a **report meta-tool** ([ADR-0005](../../adr/0005-server-side-interpretation-and-report-meta-tools.md)): interpretation, correlation, and ranking happen in deterministic Dart, not in the LLM. A small/local model produces a complete, band-classified, ranked report from a single tool call instead of orchestrating ~10 raw tools, reading offloaded files, and applying the interpretation guide itself.

## Algorithm

1. `ReportOrchestrator` runs the relevant analysis algorithms server-side (bus factor, ownership, bug hotspots, complexity, churn, logical coupling, volatility, secrets, compliance, and — opt-in — dependency freshness), reusing the existing library-first algorithms.
2. Per-metric **classifiers** (`lib/src/intelligence/interpretation/classifiers/`) map each analysis DTO into severity-banded `Finding`s using the bands documented in [`doc/INTERPRETATION_GUIDE.md`](../../INTERPRETATION_GUIDE.md).
3. The `CompoundFindingCorrelator` applies the cross-tool AND-rules — risks that only matter when two signals co-occur.
4. Findings are ranked most-severe first and returned as a bounded `ReportPayload`.

## Parameters

| Parameter | Required | Description |
| --- | --- | --- |
| `directory` | yes | The local repository path. |
| `limit` | no | Max recent commits to analyze (default: 500, see `defaultCommitLimit` in `lib/src/constants.dart`). |
| `branch` | no | Branch or commit range to scan for secrets. Defaults to current HEAD. |
| `check_freshness` | no | When `true`, performs network lookups against package registries to flag outdated dependencies. Default `false` (fully offline). |
| `allowed_emails` | no | Comma-separated allow-list of author emails for the compliance check. |

## Output Contract

Shared by all five report meta-tools (advertised via the compact `_reportOutputSchema`, [ADR-0002](../../adr/0002-mcp-tool-metadata-decorator.md)):

- `report_type` — which report was generated
- `summary` — finding counts by severity
- `top_findings` — ranked array; each finding carries `severity`, `subject`, `band`, `metric`, `value`, a ready-to-use `message`, and a compact `basis` citation tag naming the research behind the band (e.g. `Truck-factor estimation (Avelino et al. 2016)`). The offloaded full report additionally carries a per-finding `rationale` — a one-to-two-sentence explanation of why the metric predicts risk, with the citation; the offload preview strips `rationale` to protect its token budget.
- `compound_findings` — cross-tool correlated risks, the highest-priority items

If the payload exceeds the offload threshold ([ADR-0001](../../adr/0001-file-offloading-of-large-tool-outputs.md)), the offload `preview` still carries `summary`/`top_findings`/`compound_findings`, so the report stays actionable inline without a second file read.

## Foundations

The classification thresholds and compound-risk rules — and the research each one is grounded in — are documented in [`doc/INTERPRETATION_GUIDE.md`](../../INTERPRETATION_GUIDE.md). The underlying metrics inherit the academic foundations of the raw tools this report orchestrates; see the per-tool documents under `doc/tools/` and [`doc/TOOLS_ACADEMIC_FOUNDATIONS.md`](../../TOOLS_ACADEMIC_FOUNDATIONS.md).
