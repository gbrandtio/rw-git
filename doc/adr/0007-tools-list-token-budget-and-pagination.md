# 0007 — Bound the `tools/list` token cost and paginate for tiny-context clients

- **Status**: Accepted
- **Date**: 2026-07-01
- **Deciders**: rw_git maintainers
- **Related**: [ADR-0002](0002-mcp-tool-metadata-decorator.md),
  [ADR-0005](0005-server-side-interpretation-and-report-meta-tools.md)

## Context

Before a model calls any tool, an MCP client fetches `tools/list`. That response
is a **fixed tax** paid on every session: its size is subtracted from the context
budget regardless of which tools are used. With ~35 tools, each carrying a
description, an input schema, offload properties (ADR-0001), and metadata
(ADR-0002), the listing had grown large enough (~43 KB / ~12K tokens) to be a
real problem for 8–16K-context local models — the exact audience the
*Small and local models Competitive Advantage* rule prioritises.

Two separate pressures: the **total size** of the listing, and the inability of a
tiny-context client to hold even a well-trimmed full listing at once.

## Decision

Treat the `tools/list` payload as a budgeted resource, and make it chunkable.

- **Trim the fixed cost.** The verbose offload contract was removed from every
  tool's description and deferred to `get_rw_git_documentation`; each wrapped
  tool now carries only a one-sentence offload note (ADR-0001). Near-duplicate
  tools were merged (e.g. three comment tools → `evaluate_comments` with an
  `aspects` parameter; author variant folded into `analyze_code_quality`).
  `outputSchema` entries are kept compact (ADR-0002). This brought the listing
  down to ~34.6 KB / ~8.7K tokens even after adding the five report meta-tools.
- **Guard the budget.** A regression test (`tools_list_size_test.dart`) asserts
  an upper bound on the serialized `tools/list` size, so the floor cannot silently
  creep back up as tools are added.
- **Paginate on demand.** `McpServer` accepts an optional `toolsPageSize`. When
  set, `tools/list` returns a page plus an opaque base64 `nextCursor`; when null
  (the default), it returns the full listing in one response — backwards
  compatible. The cursor is validated on the way back in.
- **Order for discoverability.** The report meta-tools (ADR-0005) are registered
  first so they appear at the top of the listing and become the prominent choice
  for small models.

## Consequences

- **Positive**: the fixed per-session token cost is low enough for small local
  models to hold the full tool surface, and the regression test keeps it that
  way.
- **Positive**: clients with extremely tight context can page the surface via
  `toolsPageSize` instead of being forced to ingest it whole.
- **Positive**: tool ordering nudges models toward the one-call report tools
  before the raw per-dimension tools.
- **Negative / trade-off**: deferring the full offload contract to
  `get_rw_git_documentation` means a model that never reads that doc sees only the
  one-sentence hint. This is an accepted trade — the detailed contract is a
  one-time read, not a per-session tax.
- **Negative**: pagination adds a small amount of server complexity (opaque
  cursor encode/decode/validate). It is opt-in and off by default, so it costs
  nothing for clients that do not need it.
