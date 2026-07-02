# 0011 — Per-tool offload thresholds for large tool outputs

- **Status**: Accepted
- **Date**: 2026-07-02
- **Deciders**: rw_git maintainers
- **Related**: [ADR-0001](0001-file-offloading-of-large-tool-outputs.md)
  (amends its single-global-threshold trade-off),
  [ADR-0005](0005-server-side-interpretation-and-report-meta-tools.md),
  [ADR-0006](0006-targeted-retrieval-of-offloaded-reports.md)

## Context

ADR-0001 gates file offloading on a single global constant
(`offloadSizeThresholdBytes`, 8 KiB) and recorded per-tool thresholds as a
rejected-for-now simplification. Operating the server since then has shown
that one size does not fit two distinct tool families:

1. **Report meta-tools** (`generate_*_report`, `generate_repository_audit`).
   Their offload summary already carries the classified findings inline
   (`summary`, `top_findings`, `compound_findings` — ADR-0005), so returning
   a full report inline duplicates content the summary would deliver anyway.
   For these tools a *lower* threshold strictly reduces token cost.
2. **Compact history tools** (`get_commits_between`, `get_stats`). Their
   output is a flat list or aggregate the model almost always consumes whole
   (e.g. to write a changelog). Offloading a payload the model immediately
   reads back in full adds a write plus a read round trip and *increases*
   token cost. For these tools a *higher* threshold is cheaper.

Every other analysis tool behaves as ADR-0001 assumed, and the 8 KiB default
remains correct for them.

## Decision

- `McpToolFileOffloadDecorator` accepts an `offloadThresholdBytes`
  constructor parameter, defaulting to the global
  `offloadSizeThresholdBytes`. The threshold governs both the size gate and
  the `(>NKB offloaded to disk.)` note appended to the tool description, so
  the advertised contract always matches the behaviour.
- Per-tool overrides are centralised in `lib/src/constants.dart` as
  `perToolOffloadThresholdBytes`, a map keyed by MCP tool name (per the
  *Constants and Defaults* guardrail). The `offloadedRo(...)` helper in
  `server_registry.dart` resolves the override at registration, so production
  and tests share the wiring.
- Initial overrides, each tied to a tool-family rationale above:
  - report meta-tools → `reportToolOffloadThresholdBytes` (4 KiB);
  - `get_commits_between`, `get_stats` →
    `compactHistoryToolOffloadThresholdBytes` (16 KiB).
- Changing or adding an override is a one-site edit to the constants map and
  must carry a rationale in the constant's documentation comment.

## Consequences

- **Positive**: report meta-tools stop paying an inline-duplication tax on
  mid-sized repositories; compact history tools stop paying an offload round
  trip for payloads the model reads back whole.
- **Positive**: the mechanism is declarative — reviewers see every deviation
  from the default in one map next to its justification.
- **Negative / trade-off**: two more named constants and a map to maintain.
  Thresholds remain static per tool; dynamic sizing based on the client's
  context window was considered and rejected because MCP gives the server no
  reliable signal of the client's budget.
- ADR-0001 remains authoritative for the offload mechanism itself; only its
  "single global constant" trade-off paragraph is superseded by this record.
