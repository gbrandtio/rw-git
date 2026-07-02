# 0006 — Targeted retrieval of offloaded reports (`read_report_slice` + MCP Resources)

- **Status**: Accepted
- **Date**: 2026-07-01
- **Deciders**: rw_git maintainers
- **Related**: [ADR-0001](0001-file-offloading-of-large-tool-outputs.md)

## Context

Once a large result is offloaded to disk (ADR-0001), the model needs a way to get
data back **without** re-inflating its context. Two consumer profiles exist:

- **Small / local models** that only know how to call tools, and want a *slice*
  of the report (one key path, a page of an array) — not the whole file.
- **Standards-aware MCP clients** that can natively fetch a resource by URI via
  the protocol's `resources/read` method.

A naive "read the file" step defeats the purpose of offloading, because it pulls
the entire payload back into context. Retrieval must be *targeted* and must not
become a hole through which arbitrary files on disk can be read
(`SECURITY.md` → path traversal).

## Decision

Provide **two complementary, sandboxed retrieval paths** over the same offloaded
files:

1. **`read_report_slice` tool** — takes a `file`, an optional dot-separated
   `path` into the JSON, and `offset`/`limit` for arrays. It resolves the path,
   and if the value is an array returns a bounded page (default 50, max 500) with
   `total_length`/`offset`/`limit`; otherwise returns the resolved value.
   Wrong paths return the available keys as a `preview`, so the model can
   self-correct. This lets a tool-only model page through a big report cheaply.
2. **MCP Resources** — the offload decorator registers each written file in a
   `ResourceRegistry`, which surfaces them via `resources/list` and
   `resources/read`. The offload summary includes the file's `resource_uri`, so a
   standards-aware client can fetch the full report through the protocol.

Both paths are **sandboxed**:

- `read_report_slice` rejects any `file` whose normalised path does not contain a
  `.rw_git` segment **and** a `reports` segment — reads are confined to the
  offload directory.
- The `ResourceRegistry` only serves URIs it has itself registered during the
  session; it maps URI → absolute path and refuses anything unregistered, so it
  cannot be used to read arbitrary paths.

The `preview` from the offload summary (a `structure` map of top-level keys to type tags with array lengths) is what
makes targeting possible: the model knows what to ask for before asking.

## Consequences

- **Positive**: models retrieve exactly the slice they need, preserving the
  token savings that offloading exists to provide.
- **Positive**: two audiences are served without duplicating storage — the same
  file backs both the tool path and the resource path.
- **Positive**: both paths are allow-listed to session-registered / `.rw_git/reports`
  files, so retrieval cannot traverse to sensitive locations.
- **Negative**: the `ResourceRegistry` is in-memory and session-scoped; resource
  URIs from a previous server session are not resolvable. This matches MCP's
  session model and keeps the surface from accumulating stale entries.
- **Trade-off**: `read_report_slice`'s path language is intentionally simple
  (dot-separated keys, single array page). Deep queries (filters, projections)
  were rejected as scope creep — the classified report meta-tools (ADR-0005)
  already answer most "what matters" questions inline.
