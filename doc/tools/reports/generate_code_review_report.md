# generate_code_review_report

## Business Logic

Answers: "What should a reviewer scrutinise before merging this code?" and similar questions. A one-call code-review risk report, on the highest-churn files, covering:
- Exposed secrets.
- Complexity outliers:
    - Diff-keyword proxy plus the full genuine lexical suite.
    - Maintainability index.
    - ABC.
    - NPath.
    - Cognitive complexity.
    - Halstead delivered-bugs (estimation of bugs or errors in a chunk of code based the code's length, volume and mental effort (computed via number and total count of distinct operators and operands)).
- Clean-code heuristics.
- Ownership structure (single-owner files and Bird's et al. minor-contributor counts).
- Bug hotspots, with refactoring-explained churn discounted.

The results are pre-classified and ranked including the ranked Tornhill `refactoring_targets` list (refers to the strategic prioritization towards refactoring, targetting files that are both frequently changed and have a low code health) so the reviewer (or the reviewing agent) can go straight to the riskiest files.

This is a **report meta-tool** ([ADR-0005](../../adr/0005-server-side-interpretation-and-report-meta-tools.md)): classification and correlation happen via deterministic research-backed algorithms, not propagated for interpretation in the LLM. For comment quality on the change, `evaluate_comments` is the deep-dive path.

## Algorithm

1. `ReportOrchestrator.codeReviewReport` runs the review-relevant analyses server-side (secrets scanning on the given `branch`/range, complexity, churn + ownership from one shared git pass, bug hotspots via SZZ, refactoring detection), reusing the existing library-first algorithms; independent analyses run concurrently.
2. One bounded top-churn sample (`BoundedLexicalMetricsSampler`, ADR-0014) feeds both the full genuine lexical suite and the clean-code heuristics, so runtime stays bounded.
3. Per-metric classifiers map each DTO into severity-banded `Finding`s using the bands in [`doc/INTERPRETATION_GUIDE.md`](../../INTERPRETATION_GUIDE.md).
4. A refactoring-aware pass (the RA-SZZ insight) downgrades churn findings one band when the file's changes are explained by detected refactorings. A review must not flag paid-down debt as risk.
5. The `CompoundFindingCorrelator` escalates co-occurring risks in the code being merged. This includes genuine-McCabe-outlier × churn (Critical) and many minor contributors on a bug hotspot (High).
6. Findings are ranked most-severe first and returned as a bounded `ReportPayload`, together with the ranked Tornhill `refactoring_targets` list.

## Parameters

| Parameter | Required | Description |
| --- | --- | --- |
| `directory` | yes | The local repository path. |
| `branch` | no | Branch or commit range to scan for secrets. Defaults to current HEAD. |
| `limit` | no | Max recent commits to analyze (default: 500, see `defaultCommitLimit` in `lib/src/constants.dart`). |
| `since` | no | Only commits after this date (ISO-8601, e.g. `2024-01-01`, or a git relative phrase, e.g. `6 months ago`). |
| `until` | no | Only commits before this date (ISO-8601, e.g. `2024-12-31`, or a git relative phrase, e.g. `yesterday`). |

The report can be scoped to a date window via `since`/`until`, which are forwarded verbatim to git's own `--since=`/`--until=` date parser — no natural-language date math is performed by `rw_git` itself.

## Output Contract

Shared by all five report meta-tools (see [generate_repository_audit.md](generate_repository_audit.md#output-contract)): `report_type`, `summary`, `top_findings`, `compound_findings`; the offload `preview` mirrors the same fields so an offloaded report stays actionable inline.

## Foundations

Bands and compound-risk rules: [`doc/INTERPRETATION_GUIDE.md`](../../INTERPRETATION_GUIDE.md). Underlying metrics inherit the academic foundations of the raw tools (`detect_secrets_in_commits`, `analyze_code_quality`, `analyze_file_ownership`, `analyze_bug_hotspots`, `calculate_universal_lexical_metrics`, `analyze_clean_code`, `analyze_refactoring`); see their documents under `doc/tools/`.
