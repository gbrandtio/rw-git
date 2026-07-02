# generate_pm_report

## Business Logic

Answers: "Where are our knowledge-concentration and delivery risks?" A one-call project-management report for engineering managers covering knowledge concentration (bus factor, single-owner files), delivery bottlenecks (bug hotspots), and delivery cadence (velocity trend, Gini author concentration, burnout-window work). Each finding is framed so the narrating model can state who/what the risk is and what staffing or process action it implies.

This is a **report meta-tool** ([ADR-0005](../../adr/0005-server-side-interpretation-and-report-meta-tools.md)): classification and correlation happen in deterministic Dart, not in the LLM.

## Algorithm

1. `ReportOrchestrator.pmReport` runs the team-dynamics analyses server-side (bus factor / truck factor, file ownership concentration, bug hotspots via SZZ, commit velocity), reusing the existing library-first algorithms.
2. Per-metric classifiers map each DTO into severity-banded `Finding`s using the bands in [`doc/INTERPRETATION_GUIDE.md`](../../INTERPRETATION_GUIDE.md) (e.g. a single author owning > 50% of a file's commits with no meaningful second contributor → Critical single point of failure; a Gini author-concentration coefficient > 0.6 or > 15% of commits in the burnout window → High cadence risk).
3. The `CompoundFindingCorrelator` escalates co-occurring risks (e.g. a bug hotspot that is also single-owner).
4. Findings are ranked most-severe first and returned as a bounded `ReportPayload`.

For raw time-series buckets or release-delta detail, the raw `analyze_commit_velocity` and `analyze_release_delta` tools remain the deep-dive path.

## Parameters

| Parameter | Required | Description |
| --- | --- | --- |
| `directory` | yes | The local repository path. |
| `limit` | no | Max recent commits to analyze (default: 500, see `defaultCommitLimit` in `lib/src/constants.dart`). |

## Output Contract

Shared by all five report meta-tools — see [generate_repository_audit.md](generate_repository_audit.md#output-contract): `report_type`, `summary`, `top_findings`, `compound_findings`; the offload `preview` mirrors the same fields so an offloaded report stays actionable inline.

## Foundations

Bands and compound-risk rules: [`doc/INTERPRETATION_GUIDE.md`](../../INTERPRETATION_GUIDE.md). Underlying metrics inherit the academic foundations of the raw tools (`analyze_bus_factor`, `analyze_file_ownership`, `analyze_bug_hotspots`, `analyze_commit_velocity`); see their documents under `doc/tools/architecture/` and `doc/tools/history/`.
