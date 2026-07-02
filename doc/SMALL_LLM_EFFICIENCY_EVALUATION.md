# Small-LLM Token-Efficiency & MCP Standards Evaluation

> Staff-level review of how well `rw_git`'s MCP server meets its core business
> objective — letting **small / local LLMs** drive deep repository intelligence
> while keeping the context window tiny and token burn minimal — together with
> the standards-alignment work carried out as a result.

## 1. Verdict

The foundation is strong and, in several respects, ahead of typical open-source
MCP servers: the file-offload decorator, the inline-under-8KB rule, the
structural `preview`, the `read_report_slice` tool, and 29 academically-grounded
metrics computed locally (zero LLM tokens) are exactly the right architecture
for the stated mission.

This evaluation found and fixed three classes of gap:

1. **A self-inflicted token tax** in `tools/list` (the fixed cost every
   conversation pays up-front).
2. **A duplicated source of truth** and **stale docs** around skills/prompts.
3. **Missing, cheap, standard MCP metadata** and an **outdated protocol
   revision**.

All fixes shipped in `3.1.0`. See the CHANGELOG for the itemised list.

## 2. Token-cost model (measured)

The `tools/list` payload is the dominant fixed cost: a model must hold every
tool's schema to call tools at all, and most local runtimes (Ollama,
llama.cpp) do not cache it, so it is effectively re-paid each request.

| Stage | `tools/list` bytes | ~tokens | Notes |
|---|---:|---:|---|
| Before | ~43,000 | ~12,000 | 196-char offload paragraph + two long property descriptions stamped onto all 35 tools |
| After boilerplate trim (Phase A) | 30,160 | ~8,400 | Offload contract deferred to `get_rw_git_documentation` |
| Final (3.1.0, incl. annotations + 1 outputSchema) | 32,382 | ~9,000 | ~25% below baseline **and** now carries standard metadata it never had |
| After full outputSchema stamping (66941fd) | ~41,000 | ~11,500 | Broad-but-shallow schemas re-fattened the fixed cost without structured delivery |
| After ADR-0013 schema policy | 35,635 | ~9,900 | Schemas only where stable shapes drive `structuredContent`; every schema-declaring tool now actually returns structured output |

Measurement: `utf8.encode(jsonEncode(registry.getToolListings())).length`,
tokens estimated at ~3.6 chars/token (English + JSON). Reproduce via
`test/mcp/tools_list_size_test.dart`, which also guards against regression
(budget: 35,000 bytes).

**Per-report working budget** (e.g. a `rw-git-mcp-security-reporting` run):
`tools/list` (~9k) + one prompt (~1.3k) + a few tool calls and slice reads
(~4–8k working set) ≈ **15–18k tokens** for a focused report; a full multi-tool
deep audit stays bounded because every verbose result is offloaded and read back
in slices rather than held in context.

## 3. Model-suitability matrix

Token *need* is set by the server, so it is roughly constant across models. What
differs is whether a model has (a) enough context window to hold the tool
surface and a working set, and (b) reliable **function-calling +
instruction-following** (the model must read offloaded files iteratively rather
than hallucinate tool calls — a failure mode the project has hit before with
small models). Figures are approximate, early-2026.

| Model | Class | Ctx window | Holds tool list (~9k) | Tool-calling | Verdict for rw-git |
|---|---|---:|---|---|---|
| Gemma 2 9B / 27B | local | 8K | tight | medium | Marginal; only viable now that the floor dropped below ~9k |
| Phi-4 14B | local | 16K | yes | medium | Usable with modest headroom |
| Qwen2.5-Coder 7B / 14B / 32B | local | 32K (128K YaRN) | yes | high | **Best small-local pick** |
| Llama 3.1 8B / 3.3 70B | local | 128K | yes | high | Strong; 8B viable, 70B robust |
| Mistral Nemo 12B / Small 3 | local | 128K | yes | high | Strong |
| DeepSeek-Coder-V2-Lite 16B | local | 128K | yes | medium-high | Strong |
| Granite 3.x 8B | local | 128K | yes | high (tool-tuned) | Strong, tool-focused |
| gpt-oss 20B / 120B | local | 128K+ | yes | high | Strong where hardware allows |
| Haiku 4.5 | frontier | 200K | yes | very high | Ideal cheap frontier baseline |
| Sonnet 5 / Opus 4.8 | frontier | 200K (1M beta) | yes | very high | Flawless; overkill for cost |
| Gemini / GPT-class | frontier | 128K–2M | yes | very high | Fine |

**Practical floor:** ~16K context + competent function-calling. **Sweet spot
for the mission:** Qwen2.5-Coder 7–14B or Llama 3.1 8B locally; Haiku 4.5 as the
frontier baseline. For very small windows, `tools/list` pagination
(`RW_GIT_TOOLS_PAGE_SIZE`) lets a client fetch the tool surface in chunks.

## 4. What changed (and why it matters for small LLMs)

- **Trimmed `tools/list` boilerplate** — the single biggest token win; the
  offload contract lives once in `get_rw_git_documentation`, not 35×.
- **Standard tool annotations** (`readOnlyHint`/`idempotentHint`) — lets clients
  auto-approve the 30 read-only analysis tools, reducing round-trips for
  autonomous small-model agents; the 5 mutating tools are flagged.
- **Protocol 2025-06-18 + Resources** — offloaded reports are now first-class
  MCP resources (`resources/list` / `resources/read`) in addition to
  `read_report_slice`, aligning the bespoke offload with the spec without
  regressing the small-model path.
- **Single-source skills/prompts** — prompts are generated from canonical
  `SKILL.md` files, with a drift-guard test, so the agent guidance small models
  depend on cannot silently fall out of sync.

## 5. Remaining recommendations (non-blocking)

- ~~Expand `outputSchema` to more tools~~ — resolved the other way by
  ADR-0013: broad-but-shallow schemas were removed because the offload
  `preview` conveys the same structure at response time for free; the schemas
  that remain (report meta-tools, tiny git-op results, fixed-shape tools) now
  drive real `structuredContent` responses.
- **Academic polish** (low priority): add DOIs to the handful of uncited
  references in `TOOLS_ACADEMIC_FOUNDATIONS.md`, add a `CITATION.cff`, and make
  time-of-day heuristics (e.g. the 09:00–17:00 burnout window) timezone-aware.
- **Empirical model smoke test:** run a focused report end-to-end against a local
  Qwen2.5-Coder 7B (Ollama) to validate the trimmed schema + workflow on a real
  small model, and record the observed token usage here.

## 6. How to reproduce the measurements

```bash
# tools/list size + regression budget
dart test test/mcp/tools_list_size_test.dart

# Standard metadata (annotations / outputSchema) in tools/list
dart test test/mcp/tools_list_metadata_test.dart

# Protocol negotiation, pagination, resources
dart test test/mcp/mcp_server_protocol_test.dart

# Skills <-> prompts single source of truth
dart run tool/sync_prompts.dart --check
```
