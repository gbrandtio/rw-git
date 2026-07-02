# Architecture Decision Records (ADRs)

This directory records the significant architectural decisions made in the
`rw_git` package and its MCP server. Each record captures the **context** that
forced a decision, the **decision** itself, and the **consequences** — so that
future contributors understand not just *what* the architecture is, but *why*
it is that way.

## What is an ADR?

An Architecture Decision Record is a short, immutable document describing one
architecturally significant decision. We follow a lightweight
[MADR](https://adr.github.io/madr/)-style template. Once a decision is
`Accepted`, its ADR is not rewritten; if the decision changes, a new ADR is
added that **supersedes** the old one, and the old one is marked `Superseded
by ADR-XXXX`.

## Conventions

- **Filename**: `NNNN-short-kebab-title.md`, where `NNNN` is a zero-padded,
  monotonically increasing number.
- **Status**: one of `Proposed`, `Accepted`, `Deprecated`, `Superseded`.
- **Immutability**: prefer superseding over editing. Fix typos freely; do not
  rewrite decisions.
- **Scope**: one decision per record. If a record needs the word "and" in its
  title, consider splitting it.

These ADRs complement — they do not replace — the normative documents referenced
in [`AGENTS.md`](../../AGENTS.md): `CODING_STANDARDS.md`,
`DART_PERFORMANCE_AND_CONCURRENCY.md`, `SECURITY.md`, and `ERROR_HANDLING.md`.
Where an ADR touches those areas, it links back to the governing document.

## Index

| ADR | Title | Status |
| --- | ----- | ------ |
| [0000](0000-record-architecture-decisions.md) | Record architecture decisions | Accepted |
| [0001](0001-file-offloading-of-large-tool-outputs.md) | File offloading of large tool outputs to disk | Accepted |
| [0002](0002-mcp-tool-metadata-decorator.md) | MCP tool metadata via an outermost decorator | Accepted |
| [0003](0003-offload-cpu-bound-parsing-to-isolates.md) | Offload CPU-bound parsing to background Isolates | Accepted |
| [0004](0004-process-runner-abstraction-and-shell-less-execution.md) | Abstract process execution behind `ProcessRunner`, execute without a shell | Accepted |
| [0005](0005-server-side-interpretation-and-report-meta-tools.md) | Server-side interpretation layer and one-call report meta-tools | Accepted |
| [0006](0006-targeted-retrieval-of-offloaded-reports.md) | Targeted retrieval of offloaded reports (`read_report_slice` + MCP Resources) | Accepted |
| [0007](0007-tools-list-token-budget-and-pagination.md) | Bound the `tools/list` token cost and paginate for tiny-context clients | Accepted |
| [0008](0008-rules-pattern-for-mcp-request-dispatch.md) | Dispatch MCP JSON-RPC methods via the Rules design pattern | Accepted |
| [0009](0009-tool-registry-ordering-for-discoverability.md) | Order the tool registry for small-LLM discoverability (report tools first) | Accepted |
| [0010](0010-interpretation-threshold-change-process.md) | Interpretation thresholds: code is the source of truth, guide follows | Accepted |
| [0011](0011-per-tool-offload-thresholds.md) | Per-tool offload thresholds for large tool outputs | Accepted |
| [0012](0012-structured-logging-and-mcp-log-level-control.md) | Structured logging facade and MCP log-level control | Accepted |
| [0013](0013-structured-tool-results-and-output-schema-policy.md) | Structured tool results and the `outputSchema` advertisement policy | Accepted |
