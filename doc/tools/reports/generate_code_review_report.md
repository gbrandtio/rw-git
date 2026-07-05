# generate_code_review_report

## Business Logic

Answers: "What should a reviewer scrutinise before merging this code?" A one-call code-review risk report covering exposed secrets, complexity outliers (the diff-keyword proxy plus the full genuine lexical suite — McCabe, maintainability index, ABC, NPath, cognitive complexity, Halstead delivered-bugs — on the highest-churn files), clean-code heuristics, ownership structure (single-owner files and Bird minor-contributor counts), and bug hotspots, with refactoring-explained churn discounted. Pre-classified and ranked — plus the ranked Tornhill `refactoring_targets` list — so the reviewer (or the reviewing agent) can go straight to the riskiest files.

This is a **report meta-tool** ([ADR-0005](../../adr/0005-server-side-interpretation-and-report-meta-tools.md)): classification and correlation happen in deterministic Dart, not in the LLM. For comment quality on the change, `evaluate_comments` is the deep-dive path.

## Algorithm

1. `ReportOrchestrator.codeReviewReport` runs the review-relevant analyses server-side (secrets scanning on the given `branch`/range, complexity, churn + ownership from one shared git pass, bug hotspots via SZZ, refactoring detection), reusing the existing library-first algorithms; independent analyses run concurrently.
2. One bounded top-churn sample (`BoundedLexicalMetricsSampler`, ADR-0014) feeds both the full genuine lexical suite and the clean-code heuristics, so runtime stays bounded.
3. Per-metric classifiers map each DTO into severity-banded `Finding`s using the bands in [`doc/INTERPRETATION_GUIDE.md`](../../INTERPRETATION_GUIDE.md).
4. A refactoring-aware pass (the RA-SZZ insight) downgrades churn findings one band when the file's changes are explained by detected refactorings — a review must not flag paid-down debt as risk.
5. The `CompoundFindingCorrelator` escalates co-occurring risks in the code being merged — including genuine-McCabe-outlier × churn (Critical) and many minor contributors on a bug hotspot (High).
6. Findings are ranked most-severe first and returned as a bounded `ReportPayload`, together with the ranked Tornhill `refactoring_targets` list.

## Parameters

| Parameter | Required | Description |
| --- | --- | --- |
| `directory` | yes | The local repository path. |
| `branch` | no | Branch or commit range to scan for secrets. Defaults to current HEAD. |
| `limit` | no | Max recent commits to analyze (default: 500, see `defaultCommitLimit` in `lib/src/constants.dart`). |

## Output Contract

Shared by all five report meta-tools — see [generate_repository_audit.md](generate_repository_audit.md#output-contract): `report_type`, `summary`, `top_findings`, `compound_findings`; the offload `preview` mirrors the same fields so an offloaded report stays actionable inline.

## Foundations

Bands and compound-risk rules: [`doc/INTERPRETATION_GUIDE.md`](../../INTERPRETATION_GUIDE.md). Underlying metrics inherit the academic foundations of the raw tools (`detect_secrets_in_commits`, `analyze_code_quality`, `analyze_file_ownership`, `analyze_bug_hotspots`, `calculate_universal_lexical_metrics`, `analyze_clean_code`, `analyze_refactoring`); see their documents under `doc/tools/`.
