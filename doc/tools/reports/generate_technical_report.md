# generate_technical_report

## Business Logic

Answers: "Where is our technical debt, and which files are the riskiest to change?" A one-call technical report covering complexity, churn, ownership, bug hotspots, logical coupling, and code volatility — returned as pre-classified, ranked findings with no thresholds or cross-tool joins left for the model to apply.

This is a **report meta-tool** ([ADR-0005](../../adr/0005-server-side-interpretation-and-report-meta-tools.md)). Measured on this repository, a technical report drops from ~9 hops / ~318K worst-case read-tokens (raw-tool orchestration) to 1 hop / ~1.9K tokens, inline-complete.

## Algorithm

1. `ReportOrchestrator.technicalReport` runs the technical analysis algorithms server-side (complexity, churn, ownership, bug hotspots via SZZ, logical coupling, volatility), reusing the existing library-first algorithms.
2. Per-metric classifiers map each analysis DTO into severity-banded `Finding`s using the bands in [`doc/INTERPRETATION_GUIDE.md`](../../INTERPRETATION_GUIDE.md) — e.g. file complexity is compared against the repo's own median rather than an invented absolute cutoff.
3. The `CompoundFindingCorrelator` applies cross-tool AND-rules — e.g. a complexity outlier that also churns heavily is escalated as a defect-injection risk.
4. Findings are ranked most-severe first and returned as a bounded `ReportPayload`.

## Parameters

| Parameter | Required | Description |
| --- | --- | --- |
| `directory` | yes | The local repository path. |
| `limit` | no | Max recent commits to analyze (default: 500, see `defaultCommitLimit` in `lib/src/constants.dart`). |

## Output Contract

Shared by all five report meta-tools — see [generate_repository_audit.md](generate_repository_audit.md#output-contract): `report_type`, `summary`, `top_findings`, `compound_findings`; the offload `preview` mirrors the same fields so an offloaded report stays actionable inline.

## Foundations

Bands and compound-risk rules: [`doc/INTERPRETATION_GUIDE.md`](../../INTERPRETATION_GUIDE.md). Underlying metrics inherit the academic foundations of the raw tools (`analyze_code_quality`, `analyze_bug_hotspots`, `analyze_logical_coupling`, `analyze_code_volatility`, `analyze_bus_factor`, `analyze_file_ownership`); see their documents under `doc/tools/`.
