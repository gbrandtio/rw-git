# generate_technical_report

## Business Logic

Answers: "Where is our technical debt, and which files are the riskiest to change?". A one-call technical report covering complexity (the diff-keyword proxy plus the full genuine lexical suite — McCabe, maintainability index, ABC score, NPath, cognitive complexity, and the Halstead delivered-bugs estimate — on the highest-churn files), churn, ownership (including Bird minor-contributor structure), bug hotspots, logical coupling, code volatility, refactoring activity, architecture drift over inferred layers, clean-code heuristics, and Dart import cycles — returned as pre-classified, ranked findings plus the ranked Tornhill `refactoring_targets` list, with no thresholds or cross-tool joins left for the model to apply.

This is a **report meta-tool** ([ADR-0005](../../adr/0005-server-side-interpretation-and-report-meta-tools.md)). Measured on this repository, a technical report drops from ~9 hops / ~318K worst-case read-tokens (raw-tool orchestration) to 1 hop / ~1.9K tokens, inline-complete.

## Algorithm

1. `ReportOrchestrator.technicalReport` runs the technical analysis algorithms server-side (complexity, churn + ownership from one shared git pass, bug hotspots via SZZ, logical coupling, volatility, refactoring detection, architecture drift over layers inferred from the churned file paths), reusing the existing library-first algorithms; independent analyses run concurrently.
2. One bounded top-churn sample (`BoundedLexicalMetricsSampler`, ADR-0014) feeds the full genuine lexical suite (McCabe, maintainability index, ABC, NPath, cognitive complexity, Halstead delivered-bugs), the clean-code heuristics, and (only on Dart repositories) Tarjan import-cycle detection. Churn is already computed, so this costs no extra git calls and report runtime stays bounded.
3. Per-metric classifiers map each analysis DTO into severity-banded `Finding`s using the bands in [`doc/INTERPRETATION_GUIDE.md`](../../INTERPRETATION_GUIDE.md). The diff-keyword complexity proxy stays repo-relative, while the genuine lexical metrics use their standard absolute bands.
4. A refactoring-aware pass (the RA-SZZ insight) downgrades churn/volatility findings one band when the file's changes are explained by detected refactorings, and surfaces notable refactoring activity as a tech-debt-paydown signal.
5. The `CompoundFindingCorrelator` applies cross-tool AND-rules. For example:
    - A complexity outlier that also churns heavily is escalated as a defect-injection risk.
    - A genuine McCabe outlier that churns is the strongest such signal.
    - Many minor contributors on a bug hotspot compounds Bird's ownership signal with SZZ's history signal.
6. Findings are ranked most-severe first and returned as a bounded `ReportPayload`, together with the ranked Tornhill `refactoring_targets` list (churn percentile × complexity percentile).

## Parameters

| Parameter | Required | Description |
| --- | --- | --- |
| `directory` | yes | The local repository path. |
| `limit` | no | Max recent commits to analyze (default: 500, see `defaultCommitLimit` in `lib/src/constants.dart`). |
| `since` | no | Only commits after this date (ISO-8601, e.g. `2024-01-01`, or a git relative phrase, e.g. `6 months ago`). |
| `until` | no | Only commits before this date (ISO-8601, e.g. `2024-12-31`, or a git relative phrase, e.g. `yesterday`). |

The report can be scoped to a date window via `since`/`until`, which are forwarded verbatim to git's own `--since=`/`--until=` date parser — no natural-language date math is performed by `rw_git` itself.

## Output Contract

Shared by all five report meta-tools — see [generate_repository_audit.md](generate_repository_audit.md#output-contract): `report_type`, `summary`, `top_findings`, `compound_findings`; the offload `preview` mirrors the same fields so an offloaded report stays actionable inline.

## Foundations

Bands and compound-risk rules: [`doc/INTERPRETATION_GUIDE.md`](../../INTERPRETATION_GUIDE.md). Underlying metrics inherit the academic foundations of the raw tools (`analyze_code_quality`, `analyze_bug_hotspots`, `analyze_logical_coupling`, `analyze_code_volatility`, `analyze_bus_factor`, `analyze_file_ownership`, `calculate_universal_lexical_metrics`, `analyze_refactoring`, `analyze_architecture_drift`, `analyze_clean_code`, `analyze_dart_ast_quality`); see their documents under `doc/tools/`.
