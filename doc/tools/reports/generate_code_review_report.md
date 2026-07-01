# generate_code_review_report

## Business Logic

Answers: "What should a reviewer scrutinise before merging this code?" A one-call code-review risk report covering exposed secrets, complexity outliers, single-owner files, and bug hotspots in the code under review — pre-classified and ranked so the reviewer (or the reviewing agent) can go straight to the riskiest files.

This is a **report meta-tool** ([ADR-0005](../../adr/0005-server-side-interpretation-and-report-meta-tools.md)): classification and correlation happen in deterministic Dart, not in the LLM. For diff-specific detail, the raw `analyze_pr_diff` and `predict_merge_conflicts` tools remain the deep-dive path; `evaluate_comments` covers comment quality on the change.

## Algorithm

1. `ReportOrchestrator.codeReviewReport` runs the review-relevant analyses server-side (secrets scanning on the given `branch`/range, complexity, ownership concentration, bug hotspots via SZZ), reusing the existing library-first algorithms.
2. Per-metric classifiers map each DTO into severity-banded `Finding`s using the bands in [`doc/INTERPRETATION_GUIDE.md`](../../INTERPRETATION_GUIDE.md).
3. The `CompoundFindingCorrelator` escalates co-occurring risks in the code being merged.
4. Findings are ranked most-severe first and returned as a bounded `ReportPayload`.

## Parameters

| Parameter | Required | Description |
| --- | --- | --- |
| `directory` | yes | The local repository path. |
| `branch` | no | Branch or commit range to scan for secrets. Defaults to current HEAD. |
| `limit` | no | Max recent commits to analyze (default: 500, see `defaultCommitLimit` in `lib/src/constants.dart`). |

## Output Contract

Shared by all five report meta-tools — see [generate_repository_audit.md](generate_repository_audit.md#output-contract): `report_type`, `summary`, `top_findings`, `compound_findings`; the offload `preview` mirrors the same fields so an offloaded report stays actionable inline.

## Foundations

Bands and compound-risk rules: [`doc/INTERPRETATION_GUIDE.md`](../../INTERPRETATION_GUIDE.md). Underlying metrics inherit the academic foundations of the raw tools (`detect_secrets_in_commits`, `analyze_code_quality`, `analyze_file_ownership`, `analyze_bug_hotspots`); see their documents under `doc/tools/`.
