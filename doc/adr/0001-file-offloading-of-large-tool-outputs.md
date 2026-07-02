# 0001 — File offloading of large tool outputs to disk

- **Status**: Accepted
- **Date**: 2026-07-01
- **Deciders**: rw_git maintainers
- **Related**: [ADR-0002](0002-mcp-tool-metadata-decorator.md),
  [ADR-0005](0005-server-side-interpretation-and-report-meta-tools.md),
  [ADR-0006](0006-targeted-retrieval-of-offloaded-reports.md)
- **Amended by**: [ADR-0011](0011-per-tool-offload-thresholds.md) — the
  single-global-threshold trade-off below is superseded by per-tool
  thresholds; the offload mechanism itself is unchanged.

## Context

A core business rule of the library (`AGENTS.md` → *Context Window Competitive
Advantage* and *Small and local models Competitive Advantage*) is to keep the
token consumption of consuming LLMs to a minimum, and to work efficiently with
small or local models that have tight context windows.

Many analysis tools produce large JSON payloads. A single churn, hotspot, or
volatility analysis over a real repository can be tens or hundreds of kilobytes.
Returning that JSON inline to the model has three problems:

1. It floods the context window — often exceeding a small model's budget in a
   single tool call.
2. Most of the payload is never needed; the model typically wants a summary or a
   handful of ranked findings.
3. It couples every tool's usefulness to the model's ability to hold and re-read
   large blobs.

At the same time, **unconditionally** writing every response to disk is also
wrong: for small payloads it adds a wasted file-write plus a mandatory file-read
round trip, which *increases* both latency and tokens for the low-volume tools
(`get_stats`, `get_contributions_by_author`, …).

The mechanism must also be non-intrusive and secure: it must not let the model
write arbitrary files anywhere on disk (`SECURITY.md` → path traversal).

## Decision

Wrap analysis tools in an `McpToolFileOffloadDecorator` that, by default,
**offloads large JSON results to disk** and returns a small, actionable summary
instead of the full payload. Specifically:

- **Size-gated offloading.** Responses **below** `offloadSizeThresholdBytes`
  (8 KiB, centralised in `lib/src/constants.dart`) are returned **inline** — the
  offload round trip is not worth it. Responses at or above the threshold are
  written to disk.
- **Deterministic, sandboxed output path.** When the caller does not specify a
  destination, the decorator writes to
  `<repo>/.rw_git/reports/<tool_name>_<timestamp>.json`, creating the directory
  on demand. The base directory is derived from the tool's `directory`
  argument (or the parent of a `file_path` argument).
- **Explicit opt-out.** The model may pass `return_full_json: true` to bypass
  disk entirely and receive the full payload inline. This opt-out always wins.
- **Explicit destination, validated.** The model may pass `output_file`; the
  decorator normalises it and rejects any path that does not resolve **within**
  the repository directory (`p.isWithin`), returning a structured security-
  violation error instead of writing.
- **Actionable summary, not just a pointer.** The offload response is a small
  JSON object containing `status`, a human hint, `file`, `file_size_bytes`, and
  a schema-agnostic `preview` (a single `structure` map of top-level keys to compact type tags, e.g. `array(12)`). When
  the payload carries already-classified findings (`summary`, `top_findings`,
  `compound_findings` — see ADR-0005), a bounded slice of them is echoed into the
  preview so a small model can narrate the report **without a second read**.
- **Error passthrough.** If the wrapped tool returns a JSON object with an
  `error` key, or output that is not JSON, the decorator does not offload it — it
  returns it directly so failures stay visible (`ERROR_HANDLING.md` → never
  swallow errors).

The decorator is applied via the `offloadedRo(...)` helper in
`server_registry.dart`, so the same wiring is used in production and in tests
and cannot drift.

## Architecture

### Composition

The decorator is a transparent `McpTool` wrapper (Decorator pattern,
`CODING_STANDARDS.md` §4.7). It delegates `name`, augments `description` and
`inputSchema`, and intercepts `execute`. At registration it sits **inside** the
metadata decorator (ADR-0002):

```
McpToolWithMetadata            (ADR-0002: annotations / outputSchema)
  └─ McpToolFileOffloadDecorator   (this ADR: size-gate + disk offload)
       └─ <concrete analysis tool>   (produces the raw JSON)
```

The offload decorator adds two properties to the wrapped tool's input schema —
`output_file` (string) and `return_full_json` (boolean) — and appends a short
"`>8KB offloaded to disk`" note to the description, so the contract is
self-describing in `tools/list`.

### Execution flow

```
execute(arguments)
  │
  ├─ resolve base directory  (arguments.directory | dirname(file_path))
  ├─ rawOutput = inner.execute(arguments)
  ├─ decoded = tryJsonDecode(rawOutput)
  │     └─ if decoded is {error: …}  → return rawOutput            (passthrough)
  │
  ├─ if return_full_json               → return rawOutput          (opt-out)
  ├─ if no output_file AND size < 8KiB → return rawOutput          (inline)
  │
  ├─ resolve outputPath
  │     ├─ output_file given → normalize + assert isWithin(repo)   (else 403-style error)
  │     └─ else auto path    → <repo>/.rw_git/reports/<tool>_<ts>.json
  │                             (return rawOutput if repo dir unknown — cannot write safely)
  │
  ├─ write rawOutput to outputPath
  ├─ build summary { status, hint, file, file_size_bytes, preview }
  ├─ register file as an MCP Resource (ADR-0006) → summary.resource_uri
  └─ return jsonEncode(summary)          (FileSystemException → structured error)
```

### Retrieval

Offloaded files are addressable two ways (ADR-0006): the `read_report_slice`
tool for targeted key-path/array-slice reads by small/local models, and the MCP
`resources/read` method for standards-aware clients. The `preview` in the
offload summary tells the model exactly which keys and array lengths exist, so it
can target a slice without first reading the whole file.

## Consequences

- **Positive**: large results no longer blow the context window; the model
  receives a bounded, actionable summary and pulls only what it needs.
- **Positive**: small results stay inline, so low-volume tools pay no offload
  tax. The 8 KiB threshold bounds the inline worst case to ~2–3K tokens.
- **Positive**: writes are sandboxed to the repository (`isWithin`), and an
  unknown repo directory degrades safely to an inline return rather than writing
  somewhere unsafe.
- **Negative**: offloading writes files under `.rw_git/reports/`. Consumers
  should git-ignore that directory (the repo already does) and are responsible
  for its lifecycle; the server does not garbage-collect old reports.
- **Negative**: a model that ignores the summary and blindly re-reads the whole
  file forfeits the token savings. The `hint` and `preview` fields, and the
  meta-tools' inline findings (ADR-0005), exist to steer against this.
- **Trade-off**: the 8 KiB threshold is a single global constant. It is a
  deliberate simplification; per-tool thresholds were rejected as premature.
  *(Superseded by [ADR-0011](0011-per-tool-offload-thresholds.md), which
  introduces per-tool thresholds while keeping 8 KiB as the default.)*
