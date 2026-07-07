# generate_security_report

## Business Logic

Answers: "Is this repository leaking secrets, drifting out of compliance, or running on stale dependencies?". A one-call security report covering exposed secrets in commit history, commit compliance (signing, author domains), and opt-in dependency freshness. Exposed secrets are always Critical; a stale major dependency whose configuration also leaks a secret is correlated into one Critical compound finding.

This is a **report meta-tool** ([ADR-0005](../../adr/0005-server-side-interpretation-and-report-meta-tools.md)): classification and correlation happen via deterministic research-backed algorithms, not propagated for interpretation in the LLM.

## Algorithm

1. `ReportOrchestrator.securityReport` runs the security analyses server-side (secrets scanning via pattern + Shannon-entropy detection, compliance scanning, dependency manifest parsing with optional registry freshness lookups), reusing the existing library-first algorithms.
2. Per-metric classifiers map each DTO into severity-banded `Finding`s using the bands in [`doc/INTERPRETATION_GUIDE.md`](../../INTERPRETATION_GUIDE.md) (e.g. major version behind → Critical, minor → Moderate, patch → Low).
3. The `CompoundFindingCorrelator` correlates secret + stale-dependency co-occurrences into single Critical compound findings.
4. Findings are ranked most-severe first and returned as a bounded `ReportPayload`.

**Note**: Network access happens only when `check_freshness: true` is passed; the default run is fully offline.

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

The report can be scoped to a date window via `since`/`until`, which are forwarded verbatim to git's own `--since=`/`--until=` date parser (no natural-language date math is performed by `rw_git` itself).

## Output Contract

Shared by all five report meta-tools (see [generate_repository_audit.md](generate_repository_audit.md#output-contract)): `report_type`, `summary`, `top_findings`, `compound_findings`; the offload `preview` mirrors the same fields so an offloaded report stays actionable inline.

## Foundations

Bands and compound-risk rules: [`doc/INTERPRETATION_GUIDE.md`](../../INTERPRETATION_GUIDE.md). Underlying metrics inherit the academic foundations of the raw tools (`detect_secrets_in_commits`, `audit_compliance`, `analyze_dependency_drift`); see their documents under `doc/tools/security/` and `doc/tools/architecture/`.
